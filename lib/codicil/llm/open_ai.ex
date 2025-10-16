defmodule Codicil.LLM.OpenAI do
  @moduledoc """
  OpenAI-compatible LLM and embeddings client.

  Supports:
  - Text generation via OpenAI Chat API
  - Vector embeddings via OpenAI Embeddings API
  - Compatible with OpenAI API and local endpoints (Ollama, LM Studio, etc.)
  - Can be used with or without authentication for local models
  """

  @default_base_url "https://api.openai.com/v1"
  @default_llm_model "gpt-4o"
  @default_embedding_model "text-embedding-3-small"

  defstruct [
    :api_key,
    llm_model: @default_llm_model,
    embedding_model: @default_embedding_model,
    base_url: @default_base_url
  ]

  @type t :: %__MODULE__{
          api_key: String.t() | nil,
          llm_model: String.t(),
          embedding_model: String.t(),
          base_url: String.t()
        }

  use Codicil.LLM
  use Codicil.Embeddings

  alias Codicil.Embeddings.Result

  # LLM Implementation

  @impl Codicil.LLM
  def generate_text(%__MODULE__{api_key: api_key, llm_model: model, base_url: base_url}, prompt, opts) do
    max_tokens = Keyword.get(opts, :max_tokens, 1024)
    temperature = Keyword.get(opts, :temperature, 0.7)
    system = Keyword.get(opts, :system)

    # Build messages array
    messages =
      if system do
        [
          %{role: "system", content: system},
          %{role: "user", content: prompt}
        ]
      else
        [%{role: "user", content: prompt}]
      end

    # Build request body
    body = %{
      model: model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature
    }

    # Build headers - include auth only if api_key is present
    headers =
      [{"content-type", "application/json"}] ++
        if api_key do
          [{"authorization", "Bearer #{api_key}"}]
        else
          []
        end

    # Make API request
    case Req.post(
           "#{base_url}/chat/completions",
           json: body,
           headers: headers
         ) do
      {:ok, %{status: 200, body: response}} ->
        # Extract text from first choice
        text =
          response
          |> Map.get("choices", [])
          |> List.first()
          |> case do
            %{"message" => %{"content" => content}} -> content
            _ -> ""
          end

        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        error_message = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Embeddings Implementation

  @impl Codicil.Embeddings
  def embed(%__MODULE__{api_key: api_key, embedding_model: model, base_url: base_url}, text, _opts) do
    body = %{
      model: model,
      input: text
    }

    case make_embeddings_request(api_key, base_url, body) do
      {:ok, %{"data" => [%{"embedding" => embedding}]}} ->
        {:ok, %Result{embedding: embedding, dimensions: length(embedding)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Codicil.Embeddings
  def embed_batch(%__MODULE__{api_key: api_key, embedding_model: model, base_url: base_url}, texts, _opts) do
    body = %{
      model: model,
      input: texts
    }

    case make_embeddings_request(api_key, base_url, body) do
      {:ok, %{"data" => data}} ->
        results =
          Enum.map(data, fn %{"embedding" => embedding} ->
            %Result{embedding: embedding, dimensions: length(embedding)}
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_embeddings_request(api_key, base_url, body) do
    # Build headers - include auth only if api_key is present
    headers =
      [{"content-type", "application/json"}] ++
        if api_key do
          [{"authorization", "Bearer #{api_key}"}]
        else
          []
        end

    case Req.post(
           "#{base_url}/embeddings",
           json: body,
           headers: headers
         ) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        error_message = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
