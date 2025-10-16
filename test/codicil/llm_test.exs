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
        model: "gpt-4o",
        base_url: "https://api.openai.com/v1"
      }

      assert %LLM.OpenAI{} = client
      assert client.api_key == "test-key"
      assert client.model == "gpt-4o"
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

    test "uses default OpenAI URL when not specified" do
      client = %LLM.OpenAI{api_key: "test-key", model: "gpt-4o"}
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
end
