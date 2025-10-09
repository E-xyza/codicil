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
    alias Codicil.Function

    # Parse source file to extract function line numbers
    line_map = parse_function_lines(file)

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

      attrs = %{
        name: Atom.to_string(name),
        module: Atom.to_string(module),
        arity: arity,
        exported: exported,
        path: file,
        line: line,
        checksum: "TODO"
      }

      Function.create(attrs)
    end

    # Stop the GenServer after processing
    {:stop, :normal, state}
  end

  # HELPER FUNCTIONS

  defp via(module_name) do
    {:via, Registry, {Codicil.ModuleTracerRegistry, module_name}}
  end

  defp parse_function_lines(file_path) do
    case File.read(file_path) do
      {:ok, source} ->
        case Code.string_to_quoted(source, columns: true) do
          {:ok, ast} ->
            extract_function_lines(ast)

          {:error, _} ->
            %{}
        end

      {:error, _} ->
        %{}
    end
  end

  defp extract_function_lines(ast) do
    {_ast, line_map} =
      Macro.prewalk(ast, %{}, fn
        {:def, meta, [{name, _meta2, args} | _]} = node, acc when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          {node, Map.put(acc, {name, length(args)}, line)}

        {:defp, meta, [{name, _meta2, args} | _]} = node, acc when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          {node, Map.put(acc, {name, length(args)}, line)}

        {:defmacro, meta, [{name, _meta2, args} | _]} = node, acc when is_atom(name) and is_list(args) ->
          line = Keyword.get(meta, :line)
          {node, Map.put(acc, {name, length(args)}, line)}

        node, acc ->
          {node, acc}
      end)

    line_map
  end

  # ROUTER

  @impl true
  def handle_cast({:complete, bytecode}, state) do
    complete_impl(bytecode, state)
  end
end
