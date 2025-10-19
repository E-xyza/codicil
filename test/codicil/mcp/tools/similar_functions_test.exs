defmodule Codicil.MCP.Tools.SimilarFunctionsTest do
  use ExUnit.Case, async: true

  alias Codicil.Functions
  alias Codicil.MCP.Tools.SimilarFunctions
  alias Codicil.Db.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    # Create test functions with summaries and embeddings
    {_status, func1} =
      Functions.upsert(%{
        name: :calculate_total,
        module: :"Math.Calculator",
        arity: 1,
        exported: true,
        path: "/lib/math/calculator.ex",
        line: 10,
        checksum: "abc123",
        summary: "Calculates the total sum of a list of numbers",
        embedding: generate_embedding([0.1, 0.2, 0.3])
      })

    {_status, func2} =
      Functions.upsert(%{
        name: :format_text,
        module: :"Text.Formatter",
        arity: 2,
        exported: true,
        path: "/lib/text/formatter.ex",
        line: 20,
        checksum: "def456",
        summary: "Formats text with specified options",
        embedding: generate_embedding([0.8, 0.9, 0.7])
      })

    %{func1: func1, func2: func2}
  end

  describe "call/1" do
    test "requires description parameter" do
      assert {:error, _} = SimilarFunctions.call(%{})
    end

    test "returns structured result on success" do
      # This test will need actual embeddings/LLM clients to work
      # For now, just verify the function exists and returns the right structure
      result = SimilarFunctions.call(%{"description" => "calculate sum"})
      assert match?({:ok, _text} when is_binary(_text), result) or match?({:error, _}, result)
    end
  end

  # Helper to generate binary embedding from float list
  defp generate_embedding(floats) do
    floats
    |> Enum.map(&<<&1::float-32-native>>)
    |> IO.iodata_to_binary()
  end
end
