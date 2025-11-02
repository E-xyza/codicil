defmodule Codicil.MCP.Tools.ModuleFile do
  # MCP tool to retrieve the file path where a module is defined.
  @moduledoc false

  alias Codicil.Modules

  @doc """
  Find the file path where a module is defined.

  ## Parameters
  - `moduleName` - Module name (e.g., "MyModule" or ":gen_server")

  ## Returns
  - `{:ok, file_path}` with the path to the file
  - `{:error, reason}` if module not found
  """
  def call(%{"moduleName" => module_name}) do
    normalized_module = Codicil.MCP.normalize_module_name(module_name)

    case Modules.get(normalized_module) do
      nil ->
        {:error, "Module #{module_name} not found"}

      module ->
        {:ok, module.path}
    end
  end
end
