defmodule Codicil.MCP.Tools.ListFunctionCallees do
  use Codicil.MCP.Tool, """
  Lists all functions called by a specific source function, showing its dependencies.

  Use this tool when:
  - Understanding what a function depends on and what it calls internally
  - Seeing the call tree or execution flow from a specific function
  - Identifying which functions are invoked when specific code runs
  - Debugging: tracing execution path to understand what code will run
  - Refactoring: identifying which functions need to be updated together
  - Analyzing function behavior by examining its dependencies

  Returns: List of called functions with module name, function name, arity, and file location.
  """

  alias Codicil.Functions

  @doc """
  Find all functions called by the specified source function.

  ## Parameters
  - `functionName` - Name of the source function
  - `moduleName` - Module name (e.g., "MyModule" or ":gen_server")
  - `arity` - Function arity

  ## Returns
  - `{:ok, text}` with formatted list of callees
  - `{:error, reason}` if function not found
  """
  def call(%{"functionName" => name, "moduleName" => module, "arity" => arity}) do
    normalized_module = Codicil.MCP.normalize_module_name(module)

    case Functions.get_by_mfa({String.to_atom(normalized_module), String.to_atom(name), arity}) do
      nil ->
        {:error, "Function #{module}.#{name}/#{arity} not found"}

      source ->
        callees = Functions.list_calls(source)

        if Enum.empty?(callees) do
          {:ok, "No callees found for #{module}.#{name}/#{arity}"}
        else
          result = format_callees(callees, module, name, arity)
          {:ok, result}
        end
    end
  end

  defp format_callees(callees, module, name, arity) do
    count = length(callees)

    callee_list =
      callees
      |> Enum.map(fn callee ->
        "- #{callee.module}.#{callee.name}/#{callee.arity} (#{callee.path}:#{callee.line})"
      end)
      |> Enum.join("\n")

    """
    Found #{count} callee(s) for #{module}.#{name}/#{arity}:

    #{callee_list}
    """
  end
end
