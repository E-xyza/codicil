defmodule PrivateFunctionModule do
  def public_function(x), do: private_helper(x) + 1

  defp private_helper(x), do: x * 2
end
