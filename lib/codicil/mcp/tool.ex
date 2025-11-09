defmodule Codicil.MCP.Tool do
  @moduledoc """
  Macro for registering MCP tools with default descriptions.

  When you `use Codicil.MCP.Tool, "default description"`, this macro
  sets the @moduledoc attribute. The description can be overridden via
  application configuration at compile time.
  """

  defmacro __using__(default_description) when is_binary(default_description) do
    quote do
      # Check for compile-time override using the module name as key
      description = Application.compile_env(:codicil, __MODULE__, unquote(default_description))

      Module.register_attribute(__MODULE__, :moduledoc, persist: true)
      @moduledoc description
    end
  end

  @doc """
  Get the description for a tool module from its @moduledoc attribute.

  ## Examples

      Codicil.MCP.Tool.get_description(Codicil.MCP.Tools.FindSimilarFunctions)
  """
  def get_description(module) do
    [{_line, doc}] = module.__info__(:attributes)[:moduledoc]
    doc
  end
end
