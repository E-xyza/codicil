defmodule SourcerorTestModule do
  # This is a private function with a preceding comment
  # that should be the "documentation"
  defp private_with_comment(x) do
    x + 1
  end

  @doc "This is a public function with a docstring"
  def public_with_docstring(x) do
    # Call private function to avoid unused warning
    _ = private_with_comment(x)
    x * 2
  end

  def public_no_docstring(x) do
    x - 1
  end

  def public_with_first_line_comment(x) do
    # This is a first line comment
    x / 2
  end
end
