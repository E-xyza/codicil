defmodule Codicil.LLM.Cohere do
  @moduledoc """
  Cohere client supporting both LLM and embeddings.

  Supports:
  - Text generation via Chat API (Command models)
  - Text embeddings via Embed API
  """

  @default_llm_model "command-a-03-2025"
  @default_embedding_model "embed-english-v3.0"
  @api_base_url "https://api.cohere.ai/v1"

  defstruct [
    :api_key,
    llm_model: @default_llm_model,
    embedding_model: @default_embedding_model
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          llm_model: String.t(),
          embedding_model: String.t()
        }

  use Codicil.LLM
  use Codicil.Embeddings

  alias Codicil.Embeddings.Result

  # LLM Implementation

  @impl Codicil.LLM
  def generate_text(%__MODULE__{api_key: api_key, llm_model: model}, prompt, opts) do
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)

    body = %{
      model: model,
      message: prompt,
      temperature: temperature,
      max_tokens: max_tokens
    }

    case make_chat_request(api_key, body) do
      {:ok, %{"text" => text}} ->
        {:ok, text}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_chat_request(api_key, body) do
    case Req.post(
           "#{@api_base_url}/chat",
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        error_message = get_in(body, ["message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Embeddings Implementation

  @impl Codicil.Embeddings
  def embed(%__MODULE__{api_key: api_key, embedding_model: model}, text, opts) do
    input_type = Keyword.get(opts, :input_type, "search_document")

    body = %{
      model: model,
      texts: [text],
      input_type: input_type
    }

    case make_embed_request(api_key, body) do
      {:ok, %{"embeddings" => [embedding]}} ->
        {:ok, %Result{embedding: embedding, dimensions: length(embedding)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Codicil.Embeddings
  def embed_batch(%__MODULE__{api_key: api_key, embedding_model: model}, texts, opts) do
    input_type = Keyword.get(opts, :input_type, "search_document")

    body = %{
      model: model,
      texts: texts,
      input_type: input_type
    }

    case make_embed_request(api_key, body) do
      {:ok, %{"embeddings" => embeddings}} ->
        results =
          Enum.map(embeddings, fn embedding ->
            %Result{embedding: embedding, dimensions: length(embedding)}
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_embed_request(api_key, body) do
    case Req.post(
           "#{@api_base_url}/embed",
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        error_message = get_in(body, ["message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
