defmodule Codicil.EmbeddingsTest do
  use ExUnit.Case, async: true

  alias Codicil.Embeddings

  describe "Anthropic embeddings" do
    test "client struct has required fields" do
      client = %Embeddings.Anthropic{
        api_key: "test-key",
        model: "voyage-3"
      }

      assert client.api_key == "test-key"
      assert client.model == "voyage-3"
    end

    test "uses default model when not specified" do
      client = %Embeddings.Anthropic{api_key: "test-key"}
      assert client.model == "voyage-3"
    end
  end

  describe "embedding protocol" do
    test "protocol is implemented for Anthropic client" do
      client = %Embeddings.Anthropic{api_key: "test-key"}
      # Verify protocol functions exist (actual API calls tested in integration tests)
      assert function_exported?(Codicil.Embeddings.Anthropic, :embed, 3)
      assert function_exported?(Codicil.Embeddings.Anthropic, :embed_batch, 3)
    end

    test "Result struct holds embedding data" do
      result = %Embeddings.Result{
        embedding: [0.1, 0.2, 0.3],
        dimensions: 3
      }

      assert result.embedding == [0.1, 0.2, 0.3]
      assert result.dimensions == 3
    end
  end
end
