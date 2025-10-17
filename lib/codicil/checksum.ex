defmodule Codicil.Checksum do
  @moduledoc """
  Generates checksums for functions and modules based on their AST and documentation.
  """

  @doc """
  Generates a SHA256 checksum for a function based on its AST and documentation.

  ## Parameters
  - `ast` - The AST of the function definition
  - `docs` - The documentation string (or nil if no docs)

  ## Returns
  A hex-encoded SHA256 hash string

  ## Examples

      iex> ast = quote do: def foo(x), do: x + 1
      iex> Codicil.Checksum.function(ast, "Adds one to x")
      "a1b2c3..."
  """
  @spec function(Macro.t(), String.t() | nil) :: String.t()
  def function(ast, docs) do
    {ast, docs}
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Generates a SHA256 checksum for a module based on its bytecode.

  ## Parameters
  - `bytecode` - The compiled bytecode of the module

  ## Returns
  A hex-encoded SHA256 hash string
  """
  @spec module(binary()) :: String.t()
  def module(bytecode) do
    bytecode
    |> :crypto.hash(:sha256)
    |> Base.encode16(case: :lower)
  end
end
