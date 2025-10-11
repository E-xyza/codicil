defmodule ModuleRuntimeDependencies do
  # No compile-time dependencies (no import/require/use)
  # But calls to other modules at runtime

  def call_enum do
    Enum.map([1, 2, 3], fn x -> x * 2 end)
  end

  def call_string do
    String.upcase("hello")
  end

  def call_list do
    List.first([1, 2, 3])
  end
end
