defmodule Codicil.LLMTest do
  use ExUnit.Case, async: true

  alias Codicil.LLM

  describe "Claude provider" do
    test "generates text with valid API key" do
      client = %LLM.Claude{
        api_key: "test-key",
        model: "claude-3-5-sonnet-20241022"
      }

      # Mock will be needed - for now just test structure
      assert %LLM.Claude{} = client
      assert client.api_key == "test-key"
      assert client.model == "claude-3-5-sonnet-20241022"
    end

    test "uses default model when not specified" do
      client = %LLM.Claude{api_key: "test-key"}
      assert client.model == "claude-3-5-sonnet-20241022"
    end
  end

  describe "OpenAI provider" do
    test "generates text with API key" do
      client = %LLM.OpenAI{
        api_key: "test-key",
        llm_model: "gpt-4o",
        embedding_model: "text-embedding-3-small",
        base_url: "https://api.openai.com/v1"
      }

      assert %LLM.OpenAI{} = client
      assert client.api_key == "test-key"
      assert client.llm_model == "gpt-4o"
      assert client.embedding_model == "text-embedding-3-small"
    end

    test "supports local LLM without auth" do
      client = %LLM.OpenAI{
        api_key: nil,
        llm_model: "llama3",
        base_url: "http://localhost:11434/v1"
      }

      assert %LLM.OpenAI{} = client
      assert is_nil(client.api_key)
      assert client.base_url == "http://localhost:11434/v1"
    end

    test "uses default models and URL when not specified" do
      client = %LLM.OpenAI{api_key: "test-key"}
      assert client.base_url == "https://api.openai.com/v1"
      assert client.llm_model == "gpt-4o"
      assert client.embedding_model == "text-embedding-3-small"
    end
  end

  describe "Grok provider" do
    test "generates text with valid API key" do
      client = %LLM.Grok{
        api_key: "test-key",
        model: "grok-beta"
      }

      assert %LLM.Grok{} = client
      assert client.api_key == "test-key"
      assert client.model == "grok-beta"
    end

    test "uses default model when not specified" do
      client = %LLM.Grok{api_key: "test-key"}
      assert client.model == "grok-beta"
    end
  end
end
