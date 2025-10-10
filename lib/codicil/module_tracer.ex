defmodule Codicil.ModuleTracer do
  @moduledoc """
  GenServer that tracks compilation of a single module.

  Started when :defmodule event is received, stores compilation info,
  and processes the module when :on_module event completes it.
  """
  use GenServer

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
    {:ok, %{module: module_name, file: file_path}}
  end

  # API

  @spec complete(module_name :: module(), bytecode :: binary()) :: :ok
  def complete(module_name, bytecode) do
    GenServer.cast(via(module_name), {:complete, bytecode})
  end

  # API IMPLEMENTATION

  defp complete_impl(bytecode, %{module: module, file: file} = state) do
    alias Codicil.Functions

    # Parse source file to extract function line numbers and docs
    {line_map, doc_map} = parse_source_file(file)

    # Extract function information from disassembled bytecode
    {:beam_file, _module, exports, _attributes, _compile_info, functions} =
      :beam_disasm.file(bytecode)

    # Build set of exported function names/arities (excluding compiler-generated functions)
    exported_set =
      exports
      |> Enum.reject(fn {name, _arity, _label} ->
        name in [:__info__, :module_info] or String.starts_with?(Atom.to_string(name), "-")
      end)
      |> Enum.map(fn {name, arity, _label} -> {name, arity} end)
      |> MapSet.new()

    # Extract all functions (excluding compiler-generated functions)
    all_functions =
      functions
      |> Enum.reject(fn {:function, name, _arity, _label, _code} ->
        name in [:__info__, :module_info] or String.starts_with?(Atom.to_string(name), "-")
      end)
      |> Enum.map(fn {:function, name, arity, _label, _code} ->
        {name, arity}
      end)

    # Store functions in database
    for {name, arity} <- all_functions do
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

      Functions.create(attrs)
    end

    # Stop the GenServer after processing
    {:stop, :normal, state}
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
end
