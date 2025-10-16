defmodule Codicil.MCP.Tools.FunctionCallers do
  @moduledoc """
  MCP tool to find all functions that call a target function.
  """

  alias Codicil.Functions

  @doc """
  Find all functions that call the specified target function.

  ## Parameters
  - `functionName` - Name of the target function
  - `moduleName` - Fully qualified module name (e.g., "Elixir.MyModule")
  - `arity` - Function arity

  ## Returns
  - `{:ok, text}` with formatted list of callers
  - `{:error, reason}` if function not found
  """
  def call(%{"functionName" => name, "moduleName" => module, "arity" => arity}) do
    case Functions.get_by_mfa({String.to_atom(module), String.to_atom(name), arity}) do
      nil ->
        {:error, "Function #{module}.#{name}/#{arity} not found"}

      target ->
        callers = Functions.list_called_by(target)

        if Enum.empty?(callers) do
          {:ok, "No callers found for #{module}.#{name}/#{arity}"}
        else
          result = format_callers(callers, module, name, arity)
          {:ok, result}
        end
    end
  end

  defp format_callers(callers, module, name, arity) do
    count = length(callers)

    caller_list =
      callers
      |> Enum.map(fn caller ->
        "- #{caller.module}.#{caller.name}/#{caller.arity} (#{caller.path}:#{caller.line})"
      end)
      |> Enum.join("\n")

    """
    Found #{count} caller(s) for #{module}.#{name}/#{arity}:

    #{caller_list}
    """
  end
end
