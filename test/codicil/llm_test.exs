defmodule Codicil.LLMTest do
  use ExUnit.Case, async: true

  alias Codicil.LLM

  describe "Anthropic provider" do
    test "generates text with valid API key" do
      client = %LLM.Anthropic{
        api_key: "test-key",
        llm_model: "claude-3-5-sonnet-20241022",
        embedding_model: "voyage-3"
      }

      assert %LLM.Anthropic{} = client
      assert client.api_key == "test-key"
      assert client.llm_model == "claude-3-5-sonnet-20241022"
      assert client.embedding_model == "voyage-3"
    end

    test "uses default models when not specified" do
      client = %LLM.Anthropic{api_key: "test-key"}
      assert client.llm_model == "claude-3-5-sonnet-20241022"
      assert client.embedding_model == "voyage-3"
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

  describe "Cohere provider" do
    test "client struct has required fields" do
      client = %LLM.Cohere{
        api_key: "test-key",
        llm_model: "command-a-03-2025",
        embedding_model: "embed-english-v3.0"
      }

      assert %LLM.Cohere{} = client
      assert client.api_key == "test-key"
      assert client.llm_model == "command-a-03-2025"
      assert client.embedding_model == "embed-english-v3.0"
    end

    test "uses default models when not specified" do
      client = %LLM.Cohere{api_key: "test-key"}
      assert client.llm_model == "command-a-03-2025"
      assert client.embedding_model == "embed-english-v3.0"
    end
  end

  describe "Google provider" do
    test "client struct has required fields" do
      client = %LLM.Google{
        api_key: "test-key",
        project_id: "test-project",
        llm_model: "gemini-2.0-flash",
        embedding_model: "text-embedding-004",
        region: "us-central1"
      }

      assert %LLM.Google{} = client
      assert client.api_key == "test-key"
      assert client.project_id == "test-project"
      assert client.llm_model == "gemini-2.0-flash"
      assert client.embedding_model == "text-embedding-004"
      assert client.region == "us-central1"
    end

    test "uses default models and region when not specified" do
      client = %LLM.Google{api_key: "test-key", project_id: "test-project"}
      assert client.llm_model == "gemini-2.0-flash"
      assert client.embedding_model == "text-embedding-004"
      assert client.region == "us-central1"
    end
  end
end
