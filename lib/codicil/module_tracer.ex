defmodule Codicil.ModuleTracer do
  @moduledoc """
  GenServer that tracks compilation of a single module.

  Started when :defmodule event is received, stores compilation info,
  and processes the module when :on_module event completes it.
  """
  use GenServer

  alias Codicil.Checksum
  alias Codicil.Functions
  alias Codicil.Modules
  alias Codicil.RateLimiter

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
  @spec add_dependency(
          dependent :: module(),
          dependency :: module(),
          type :: :compiler | :runtime
        ) ::
          :ok

  def complete(module_name, bytecode) do
    GenServer.cast(via(module_name), {:complete, bytecode})
  end

  @call_opcodes ~w[call call_only call_last call_ext call_ext_only call_ext_last]a

  defguardp is_call(bytecode_instr)
            when is_tuple(bytecode_instr) and elem(bytecode_instr, 0) in @call_opcodes

  defp complete_impl(bytecode, %{module: module, file: file, dependencies: dependencies} = state) do
    # Extract module info from bytecode
    {:beam_file, ^module, exports, attributes, _compile_info, functions} =
      :beam_disasm.file(bytecode)

    # Get module version attribute (auto-generated hash of module contents)
    module_checksum =
      case List.keyfind(attributes, :vsn, 0) do
        {:vsn, [vsn]} when is_integer(vsn) ->
          Integer.to_string(vsn)

        {:vsn, [vsn]} when is_list(vsn) ->
          :erlang.list_to_binary(vsn) |> Base.encode16(case: :lower)

        _ ->
          Checksum.module(bytecode)
      end

    # Create or update module record
    {:ok, _module_record} =
      Modules.upsert(%{
        id: module,
        path: file,
        checksum: module_checksum
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

    # Parse source file to extract function ASTs, line numbers, and leading comments
    {line_map, comment_docs_map, ast_map} = parse_source_file(file)

    # Use comment docs for now - will update with @doc after module loads
    doc_map = comment_docs_map

    # Build set of exported function names/arities (excluding compiler-generated functions)
    exported_set = for {name, arity, _label} <- exports, into: MapSet.new(), do: {name, arity}

    # Track which functions exist in this compilation (for retirement)
    {seen_functions, runtime_modules} =
      for {:function, name, arity, _label, bytecode_instrs} <- functions,
          name not in ~w[__info__ module_info]a,
          reduce: {MapSet.new(), MapSet.new()} do
        {seen, modules_so_far} ->
        # Store functions in database
        exported = MapSet.member?(exported_set, {name, arity})
        line = Map.get(line_map, {name, arity}, 0)
        docs = Map.get(doc_map, {name, arity})
        fun_ast = Map.get(ast_map, {name, arity})

        # Generate function checksum from AST and docs
        checksum = if fun_ast, do: Checksum.function(fun_ast, docs), else: "TODO"

        # Convert AST back to source code
        source_code = if fun_ast, do: Sourceror.to_string(fun_ast), else: nil

        attrs = %{
          name: Atom.to_string(name),
          module: Atom.to_string(module),
          arity: arity,
          exported: exported,
          path: file,
          line: line,
          docs: docs,
          code: source_code,
          checksum: checksum
        }

        # Upsert function and check if it was updated or stayed the same
        {status, function} = Functions.upsert(attrs)

        # Enqueue for async processing only if checksum changed or function is new
        # {:ok, _} means it was created or updated
        # {:same, _} means checksum matched, no change
        if status == :ok do
          RateLimiter.enqueue(%{
            id: function.id,
            name: name,
            module: module,
            path: file,
            docs: docs
          })
        end

        # Extract and store function calls from bytecode
        called_funs =
          for instr <- bytecode_instrs, is_call(instr), uniq: true do
            case elem(instr, 2) do
              # External calls: {:call_ext*, arity, {:extfunc, Module, :function, arity}}
              {:extfunc, mod, fun, arity} -> {mod, fun, arity}
              # Local calls: {:call*, arity, {Module, :function, arity}}
              mfa -> mfa
            end
          end

        updated_modules =
          for mfa <- called_funs, into: modules_so_far do
            callee =
              if existing = Functions.get_by_mfa(mfa) do
                existing
              else
                {_status, placeholder} = Functions.create_placeholder(mfa)
                placeholder
              end

            Functions.add_call(function, callee)

            elem(mfa, 0)
          end

        # Track this function as seen
        updated_seen = MapSet.put(seen, {name, arity})

        {updated_seen, updated_modules}
      end

    # Retire functions that no longer exist in this module
    existing_functions = Functions.list_by_module(module)

    for existing <- existing_functions do
      key = {String.to_atom(existing.name), existing.arity}

      unless MapSet.member?(seen_functions, key) do
        Functions.delete(existing)
      end
    end

    # Process runtime dependencies
    runtime_modules
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

    # Update docs from compiled module
    update_function_docs(module, bytecode)

    # Stop the GenServer after processing
    {:stop, :normal, state}
  end

  defp update_function_docs(module, bytecode) do
    # Run predoc callback if configured (e.g., in tests to write beam file to disk)
    if callback = Application.get_env(:codicil, :predoc_callback) do
      callback.(module, bytecode)
    end

    # Poll until module is available (compilation complete)
    wait_for_module(module, 50, 10)

    # Extract docs from the loaded module
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, docs} ->
        for {{:function, name, arity}, _, _, doc, _} <- docs do
          doc_string =
            case doc do
              %{"en" => text} -> String.trim(text)
              :hidden -> nil
              :none -> nil
            end

          if doc_string do
            case Functions.get_by_mfa({module, name, arity}) do
              nil -> :ok
              function -> Functions.update(function, %{docs: doc_string})
            end
          end
        end

      {:error, _reason} ->
        :ok
    end
  end

  defp wait_for_module(_module, _interval, 0), do: :timeout

  defp wait_for_module(module, interval, retries) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        :ok

      {:error, _} ->
        Process.sleep(interval)
        wait_for_module(module, interval, retries - 1)
    end
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
        # Parse with Sourceror for ASTs and leading comments
        sourceror_ast = Sourceror.parse_string!(source)
        extract_function_metadata_sourceror(sourceror_ast)

      {:error, _} ->
        {%{}, %{}, %{}}
    end
  end

  defp extract_function_metadata_sourceror(ast) do
    {_ast, {line_map, doc_map, ast_map}} =
      Macro.prewalk(ast, {%{}, %{}, %{}}, fn
        # Match def - extract leading comments as docs
        {:def, meta, [{name, _meta2, args} | _]} = node, {lines, docs, asts}
        when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          key = {name, length(args)}
          lines = Map.put(lines, key, line)
          asts = Map.put(asts, key, node)

          # Extract leading comments from Sourceror metadata
          docs =
            case extract_leading_comments(meta) do
              nil -> docs
              comments -> Map.put(docs, key, comments)
            end

          {node, {lines, docs, asts}}

        # Match defp - extract leading comments as docs
        {:defp, meta, [{name, _meta2, args} | _]} = node, {lines, docs, asts}
        when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          key = {name, length(args)}
          lines = Map.put(lines, key, line)
          asts = Map.put(asts, key, node)

          # Extract leading comments from Sourceror metadata
          docs =
            case extract_leading_comments(meta) do
              nil -> docs
              comments -> Map.put(docs, key, comments)
            end

          {node, {lines, docs, asts}}

        # Match defmacro - extract leading comments as docs
        {:defmacro, meta, [{name, _meta2, args} | _]} = node, {lines, docs, asts}
        when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          key = {name, length(args)}
          lines = Map.put(lines, key, line)
          asts = Map.put(asts, key, node)

          # Extract leading comments from Sourceror metadata
          docs =
            case extract_leading_comments(meta) do
              nil -> docs
              comments -> Map.put(docs, key, comments)
            end

          {node, {lines, docs, asts}}

        node, acc ->
          {node, acc}
      end)

    {line_map, doc_map, ast_map}
  end

  # Extract leading comments from Sourceror metadata
  defp extract_leading_comments(meta) do
    case Keyword.get(meta, :leading_comments) do
      nil ->
        nil

      [] ->
        nil

      comments ->
        comments
        |> Enum.map(& &1.text)
        |> Enum.map(&String.trim_leading(&1, "# "))
        |> Enum.join("\n")
    end
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
