defmodule Codicil.ModuleTracer do
  @moduledoc """
  GenServer that tracks compilation of a single module.

  Started when :defmodule event is received, stores compilation info,
  and processes the module when :on_module event completes it.
  """
  use GenServer

  alias Codicil.Functions
  alias Codicil.Modules

  # BOILERPLATE & INITIALIZATION

  def start_link(module_name, file_path) do
    GenServer.start_link(
      __MODULE__,
      {module_name, file_path},
      name: via(module_name)
    )
  end

  @impl true
  def init({module_name, file_path}) do
    {:ok, %{module: module_name, file: file_path, dependencies: []}}
  end

  # API

  @spec complete(module_name :: module(), bytecode :: binary()) :: :ok
  @spec add_dependency(dependent :: module(), dependency :: module(), type :: :compiler | :runtime) ::
          :ok

  def complete(module_name, bytecode) do
    GenServer.cast(via(module_name), {:complete, bytecode})
  end

  @call_opcodes ~w[call call_only call_last call_ext call_ext_only call_ext_last]a

  defguardp is_call(bytecode_instr)
            when is_tuple(bytecode_instr) and elem(bytecode_instr, 0) in @call_opcodes

  defp complete_impl(bytecode, %{module: module, file: file, dependencies: dependencies} = state) do
    # Create or update module record
    {:ok, _module_record} =
      Modules.upsert(%{
        id: module,
        path: file,
        checksum: "TODO"
      })

    # Clear old dependencies before inserting new ones
    Modules.delete_all_dependencies(module)

    # Store module dependencies (deduplicate first)
    dependencies
    |> Enum.uniq()
    |> Enum.each(fn {dependency, type} ->
      # Ensure dependency module record exists (placeholder)
      {:ok, _} = Modules.upsert(%{id: dependency, path: "unknown", checksum: "TODO"})

      # Create dependency relationship
      Modules.create_dependency(%{
        dependent_id: module,
        dependency_id: dependency,
        type: type
      })
    end)

    # Parse source file to extract function line numbers and docs
    {line_map, doc_map} = parse_source_file(file)

    # Extract function information from disassembled bytecode
    {:beam_file, _module, exports, _attributes, _compile_info, functions} =
      :beam_disasm.file(bytecode)

    # Build set of exported function names/arities (excluding compiler-generated functions)
    exported_set = for {name, arity, _label} <- exports, into: MapSet.new(), do: {name, arity}

    for {:function, name, arity, _label, code} <- functions,
        name not in ~w[__info__ module_info]a,
        reduce: MapSet.new() do
      modules_so_far ->
      # Store functions in database
      exported = MapSet.member?(exported_set, {name, arity})
      line = Map.get(line_map, {name, arity}, 0)
      docs = Map.get(doc_map, {name, arity})

      attrs = %{
        name: Atom.to_string(name),
        module: Atom.to_string(module),
        arity: arity,
        exported: exported,
        path: file,
        line: line,
        docs: docs,
        checksum: "TODO"
      }

      {:ok, function} = Functions.upsert(attrs)

      # Extract and store function calls from bytecode
      called_funs =
        for instr <- code, is_call(instr), uniq: true do
          case elem(instr, 2) do
            # External calls: {:call_ext*, arity, {:extfunc, Module, :function, arity}}
            {:extfunc, mod, fun, arity} -> {mod, fun, arity}
            # Local calls: {:call*, arity, {Module, :function, arity}}
            mfa -> mfa
          end
        end

      for mfa <- called_funs, into: modules_so_far do
        callee =
          case Functions.get_by_mfa(mfa) do
            nil ->
              {:ok, placeholder} = Functions.create_placeholder(mfa)
              placeholder

            existing ->
              existing
          end

        Functions.add_call(function, callee)

        elem(mfa, 0)
      end
    end
    |> Enum.reject(&(&1 == module))
    |> Enum.each(fn dependency ->
      # Ensure dependency module record exists (placeholder)
      {:ok, _} = Modules.upsert(%{id: dependency, path: "unknown", checksum: "TODO"})

      # Create dependency relationship
      Modules.create_dependency(%{
        dependent_id: module,
        dependency_id: dependency,
        type: :runtime
      })
    end)

    # Stop the GenServer after processing
    {:stop, :normal, state}
  end

  def add_dependency(dependent, dependency, type) do
    GenServer.cast(via(dependent), {:add_dependency, dependency, type})
  end

  defp add_dependency_impl(dependency, type, state) do
    # Add dependency to state's dependency list
    updated_dependencies = [{dependency, type} | state.dependencies]
    {:noreply, %{state | dependencies: updated_dependencies}}
  end

  # HELPER FUNCTIONS

  defp via(module_name) do
    {:via, Registry, {Codicil.ModuleTracerRegistry, module_name}}
  end

  defp parse_source_file(file_path) do
    case File.read(file_path) do
      {:ok, source} ->
        case Code.string_to_quoted(source, columns: true) do
          {:ok, ast} ->
            extract_function_metadata(ast)

          {:error, _} ->
            {%{}, %{}}
        end

      {:error, _} ->
        {%{}, %{}}
    end
  end

  defp extract_function_metadata(ast) do
    {_ast, {line_map, doc_map}} =
      Macro.prewalk(ast, {%{}, %{}}, fn
        # Match @doc attribute followed by function definition
        {:@, _, [{:doc, _, [doc_string]}]} = node, {lines, docs} when is_binary(doc_string) ->
          # Strip trailing newlines from doc string
          trimmed_doc = String.trim_trailing(doc_string)
          {node, {lines, Map.put(docs, :pending_doc, trimmed_doc)}}

        # Match @doc false
        {:@, _, [{:doc, _, [false]}]} = node, {lines, docs} ->
          {node, {lines, Map.put(docs, :pending_doc, :hidden)}}

        # Match def with previous @doc
        {:def, meta, [{name, _meta2, args} | _]} = node, {lines, docs}
        when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          key = {name, length(args)}
          lines = Map.put(lines, key, line)

          docs =
            case Map.get(docs, :pending_doc) do
              nil -> docs
              :hidden -> Map.delete(docs, :pending_doc)
              doc -> docs |> Map.put(key, doc) |> Map.delete(:pending_doc)
            end

          {node, {lines, docs}}

        # Match defp with previous @doc
        {:defp, meta, [{name, _meta2, args} | _]} = node, {lines, docs}
        when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          key = {name, length(args)}
          lines = Map.put(lines, key, line)

          docs =
            case Map.get(docs, :pending_doc) do
              nil -> docs
              :hidden -> Map.delete(docs, :pending_doc)
              doc -> docs |> Map.put(key, doc) |> Map.delete(:pending_doc)
            end

          {node, {lines, docs}}

        # Match defmacro with previous @doc
        {:defmacro, meta, [{name, _meta2, args} | _]} = node, {lines, docs}
        when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          key = {name, length(args)}
          lines = Map.put(lines, key, line)

          docs =
            case Map.get(docs, :pending_doc) do
              nil -> docs
              :hidden -> Map.delete(docs, :pending_doc)
              doc -> docs |> Map.put(key, doc) |> Map.delete(:pending_doc)
            end

          {node, {lines, docs}}

        node, acc ->
          {node, acc}
      end)

    # Remove :pending_doc if it exists
    doc_map = Map.delete(doc_map, :pending_doc)

    {line_map, doc_map}
  end

  # ROUTER

  @impl true
  def handle_cast({:complete, bytecode}, state) do
    complete_impl(bytecode, state)
  end

  def handle_cast({:add_dependency, dependency, type}, state) do
    add_dependency_impl(dependency, type, state)
  end
end
