defmodule Codicil.MCP.Tools.FunctionCode do
  # MCP tool to retrieve function code with preceding module-level imports and aliases.
  @moduledoc false

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
      code = build_code_output(directives, function.code)
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

  defp build_code_output([], function_code), do: function_code

  defp build_code_output(directives, function_code) do
    directive_code = Enum.join(directives, "\n")
    "#{directive_code}\n\n#{function_code}"
  end
end
