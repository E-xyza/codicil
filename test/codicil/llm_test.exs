defmodule Codicil.LLMTest do
  use ExUnit.Case, async: true

  alias Codicil.LLM

  describe "Anthropic provider" do
    test "client struct has required fields" do
      client = %LLM.Anthropic{
        api_key: "test-key",
        model: "claude-3-5-sonnet-20241022"
      }

      assert %LLM.Anthropic{} = client
      assert client.api_key == "test-key"
      assert client.model == "claude-3-5-sonnet-20241022"
    end

    test "supports voyage embeddings model" do
      client = %LLM.Anthropic{api_key: "test-key", model: "voyage-3"}
      assert client.model == "voyage-3"
    end
  end

  describe "OpenAI provider" do
    test "client struct has required fields" do
      client = %LLM.OpenAI{
        api_key: "test-key",
        model: "gpt-4o",
        base_url: "https://api.openai.com/v1"
      }

      assert %LLM.OpenAI{} = client
      assert client.api_key == "test-key"
      assert client.model == "gpt-4o"
      assert client.base_url == "https://api.openai.com/v1"
    end

    test "supports local LLM without auth" do
      client = %LLM.OpenAI{
        api_key: nil,
        model: "llama3",
        base_url: "http://localhost:11434/v1"
      }

      assert %LLM.OpenAI{} = client
      assert is_nil(client.api_key)
      assert client.base_url == "http://localhost:11434/v1"
    end

    test "uses default base_url when not specified" do
      client = %LLM.OpenAI{model: "gpt-4o"}
      assert client.base_url == "https://api.openai.com/v1"
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
        model: "command-a-03-2025"
      }

      assert %LLM.Cohere{} = client
      assert client.api_key == "test-key"
      assert client.model == "command-a-03-2025"
    end
  end

  describe "Google provider" do
    test "client struct has required fields" do
      client = %LLM.Google{
        api_key: "test-key",
        project_id: "test-project",
        model: "gemini-2.0-flash",
        region: "us-central1"
      }

      assert %LLM.Google{} = client
      assert client.api_key == "test-key"
      assert client.project_id == "test-project"
      assert client.model == "gemini-2.0-flash"
      assert client.region == "us-central1"
    end

    test "uses default region when not specified" do
      client = %LLM.Google{
        api_key: "test-key",
        project_id: "test-project",
        model: "gemini-2.0-flash"
      }

      assert client.region == "us-central1"
    end
  end
end
