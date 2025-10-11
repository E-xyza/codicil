defmodule RemoteCallsModule do
  # TODO: Add test for anonymous functions later
  def call_external(list) do
    # Call Enum.count/1 from standard library
    Enum.count(list)
  end

  def call_string_functions(text) do
    # Multiple remote calls
    text
    |> String.upcase()
    |> String.trim()
  end
end
