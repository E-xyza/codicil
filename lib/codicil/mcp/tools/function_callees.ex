defmodule Codicil.MCP.Tools.FunctionCallees do
  @moduledoc """
  MCP tool to find all functions called by a source function.
  """

  alias Codicil.Functions

  @doc """
  Find all functions called by the specified source function.

  ## Parameters
  - `functionName` - Name of the source function
  - `moduleName` - Fully qualified module name (e.g., "Elixir.MyModule")
  - `arity` - Function arity

  ## Returns
  - `{:ok, text}` with formatted list of callees
  - `{:error, reason}` if function not found
  """
  def call(%{"functionName" => name, "moduleName" => module, "arity" => arity}) do
    case Functions.get_by_mfa({String.to_atom(module), String.to_atom(name), arity}) do
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
