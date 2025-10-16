defmodule Codicil.LLM.Anthropic do
  @moduledoc """
  Anthropic client for both LLM (Claude) and embeddings (Voyage AI).

  Supports:
  - Text generation via Claude models
  - Vector embeddings via Voyage AI models
  """

  @default_llm_model "claude-3-5-sonnet-20241022"
  @default_embedding_model "voyage-3"

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

  @api_base_url "https://api.anthropic.com/v1"

  # LLM Implementation

  @impl Codicil.LLM
  def generate_text(%__MODULE__{api_key: api_key, llm_model: model}, prompt, opts) do
    max_tokens = Keyword.get(opts, :max_tokens, 1024)
    temperature = Keyword.get(opts, :temperature, 0.7)
    system = Keyword.get(opts, :system)

    # Build messages array
    messages = [
      %{
        role: "user",
        content: prompt
      }
    ]

    # Build request body
    body = %{
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      messages: messages
    }

    body =
      if system do
        Map.put(body, :system, system)
      else
        body
      end

    # Make API request
    case Req.post(
           "#{@api_base_url}/messages",
           json: body,
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", "2023-06-01"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: response}} ->
        # Extract text from first content block
        text =
          response
          |> Map.get("content", [])
          |> List.first()
          |> case do
            %{"text" => text} -> text
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
  def embed(%__MODULE__{api_key: api_key, embedding_model: model}, text, opts) do
    input_type = Keyword.get(opts, :input_type, "passage")

    body = %{
      model: model,
      input: text,
      input_type: input_type
    }

    case make_embeddings_request(api_key, body) do
      {:ok, %{"embedding" => embedding, "dimensions" => dimensions}} ->
        {:ok, %Result{embedding: embedding, dimensions: dimensions}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Codicil.Embeddings
  def embed_batch(%__MODULE__{api_key: api_key, embedding_model: model}, texts, opts) do
    input_type = Keyword.get(opts, :input_type, "passage")

    body = %{
      model: model,
      inputs: texts,
      input_type: input_type
    }

    case make_embeddings_request(api_key, body) do
      {:ok, %{"embeddings" => embeddings}} ->
        results =
          Enum.map(embeddings, fn %{"embedding" => emb, "dimensions" => dims} ->
            %Result{embedding: emb, dimensions: dims}
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_embeddings_request(api_key, body) do
    case Req.post(
           "#{@api_base_url}/embeddings",
           json: body,
           headers: [
             {"x-api-key", api_key},
             {"content-type", "application/json"}
           ]
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
