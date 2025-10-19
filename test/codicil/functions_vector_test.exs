defmodule Codicil.FunctionsVectorTest do
  use ExUnit.Case, async: false

  alias Codicil.Functions
  alias Codicil.Db.Repo
  alias Codicil.Modules

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "find_similar/2" do
    test "returns functions ordered by vector similarity" do
      # Create module
      {:ok, _mod} = Modules.create(%{id: TestModule, path: "/lib/test.ex", checksum: "abc"})

      # Create functions with vector embeddings
      {:ok, func1} =
        Functions.create(%{
          name: :calculate_sum,
          module: TestModule,
          arity: 1,
          exported: true,
          path: "/lib/test.ex",
          line: 10,
          checksum: "func1",
          summary: "Calculates the sum of numbers",
          embedding: encode_vector([1.0, 0.0, 0.0])
        })

      {:ok, _func2} =
        Functions.create(%{
          name: :format_text,
          module: TestModule,
          arity: 1,
          exported: true,
          path: "/lib/test.ex",
          line: 20,
          checksum: "func2",
          summary: "Formats text output",
          embedding: encode_vector([0.0, 1.0, 0.0])
        })

      {:ok, func3} =
        Functions.create(%{
          name: :add_numbers,
          module: TestModule,
          arity: 2,
          exported: true,
          path: "/lib/test.ex",
          line: 30,
          checksum: "func3",
          summary: "Adds two numbers together",
          embedding: encode_vector([0.9, 0.1, 0.0])
        })

      # Search for functions similar to [1.0, 0.0, 0.0] (should match func1 best, then func3)
      query_vector = [1.0, 0.0, 0.0]
      results = Functions.find_similar(query_vector, limit: 10)

      assert length(results) == 3
      # First result should be func1 (exact match)
      assert hd(results).id == func1.id
      # Second result should be func3 (close match)
      assert Enum.at(results, 1).id == func3.id
    end

    test "returns empty list when no functions have embeddings" do
      {:ok, _mod} = Modules.create(%{id: TestModule, path: "/lib/test.ex", checksum: "abc"})

      {:ok, _func} =
        Functions.create(%{
          name: :no_embedding,
          module: TestModule,
          arity: 0,
          exported: true,
          path: "/lib/test.ex",
          line: 5,
          checksum: "func1"
        })

      results = Functions.find_similar([1.0, 0.0, 0.0], limit: 10)
      assert results == []
    end
  end

  # Helper to encode vector as binary (float32 little-endian)
  defp encode_vector(floats) do
    floats
    |> Enum.map(&<<&1::float-32-native>>)
    |> IO.iodata_to_binary()
  end
end
