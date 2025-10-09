defmodule DocumentedModule do
  @moduledoc """
  This is a test module with documentation.
  """

  @doc """
  Multiplies a number by two.
  """
  def double(x), do: x * 2

  @doc false
  def hidden_function(x), do: x + 1

  def undocumented_function(x), do: x - 1
end
