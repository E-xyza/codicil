defmodule Codicil.MCP.Tools.GetFunctionSourceCode do
  use Codicil.MCP.Tool, """
  Get complete source code for a function with full context: module directives (use/alias/import) and file location.

  IMPORTANT: Use this tool instead of grep or reading files directly. It provides the complete function with all necessary context.

  Use this tool when:
  - You need to read or examine a specific function's implementation
  - Understanding how a function works requires seeing its full context
  - Reviewing code before making changes

  Examples:
  - Get User.create/1 with all its imports and aliases to understand dependencies
  - Read a controller action with its plug declarations
  - Examine a GenServer callback with its use directives

  Returns: Complete function source with file path, line number, and module-level directives.
  """

  alias Codicil.Functions
  alias Codicil.Modules

  @doc """
  Get the code for a function, including preceding module-level use/alias/import statements.

  ## Parameters
  - `moduleName` - Module name (e.g., "MyModule")
  - `functionName` - Function name (e.g., "process")
  - `arity` - Function arity (number of arguments)

  ## Returns
  - `{:ok, code_string}` with use/alias/import statements followed by function code
  - `{:error, reason}` if function or module not found
  """
  def call(%{"moduleName" => module_name, "functionName" => function_name, "arity" => arity}) do
    normalized_module = Codicil.MCP.normalize_module_name(module_name)

    with {:ok, function} <- get_function(normalized_module, function_name, arity),
         {:ok, module} <- get_module(normalized_module),
         {:ok, source} <- File.read(module.path),
         {:ok, directives} <- extract_directives(source) do
      code = build_code_output(directives, function)
      {:ok, code}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_function(module, name, arity) do
    module_atom = String.to_atom(module)
    name_atom = String.to_atom(name)

    case Functions.get_by_mfa({module_atom, name_atom, arity}) do
      nil -> {:error, "Function #{name}/#{arity} not found in module #{module}"}
      function -> {:ok, function}
    end
  end

  defp get_module(module_name) do
    case Modules.get(module_name) do
      nil -> {:error, "Module #{module_name} not found"}
      module -> {:ok, module}
    end
  end

  defp extract_directives(source) do
    case Sourceror.parse_string(source) do
      {:ok, ast} ->
        directives = collect_directives(ast)
        {:ok, directives}

      {:error, _} ->
        {:error, "Failed to parse source file"}
    end
  end

  defp collect_directives(ast) do
    {_ast, directives} =
      Macro.prewalk(ast, [], fn node, acc ->
        case node do
          # Match use directive
          {:use, _meta, [_module | _rest]} ->
            code = Sourceror.to_string(node)
            {node, [code | acc]}

          # Match alias directive
          {:alias, _meta, _args} ->
            code = Sourceror.to_string(node)
            {node, [code | acc]}

          # Match import directive
          {:import, _meta, _args} ->
            code = Sourceror.to_string(node)
            {node, [code | acc]}

          # Skip everything else
          _ ->
            {node, acc}
        end
      end)

    Enum.reverse(directives)
  end

  defp build_code_output([], function) do
    build_with_location(function)
  end

  defp build_code_output(directives, function) do
    directive_code = Enum.join(directives, "\n")
    location_header = build_location_header(function)
    "#{directive_code}\n\n#{location_header}\n#{function.code}"
  end

  defp build_with_location(function) do
    location_header = build_location_header(function)
    "#{location_header}\n#{function.code}"
  end

  defp build_location_header(function) do
    "# #{function.path}:#{function.line}"
  end
end
