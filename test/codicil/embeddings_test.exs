defmodule Codicil.EmbeddingsTest do
  use ExUnit.Case, async: true

  alias Codicil.Embeddings
  alias Codicil.LLM.Anthropic

  describe "Anthropic embeddings" do
    test "client struct has required fields" do
      client = %Anthropic{
        api_key: "test-key",
        llm_model: "claude-3-5-sonnet-20241022",
        embedding_model: "voyage-3"
      }

      assert client.api_key == "test-key"
      assert client.embedding_model == "voyage-3"
      assert client.llm_model == "claude-3-5-sonnet-20241022"
    end

    test "uses default models when not specified" do
      client = %Anthropic{api_key: "test-key"}
      assert client.embedding_model == "voyage-3"
      assert client.llm_model == "claude-3-5-sonnet-20241022"
    end
  end

  describe "embedding protocol" do
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
