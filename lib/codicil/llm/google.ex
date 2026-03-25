defmodule Codicil.LLM.Google do
  # Google Vertex AI client supporting both LLM and embeddings.
  #
  # Supports:
  # - Text generation via Gemini models
  # - Text embeddings via Vertex AI API
  #
  # Requires Google Cloud credentials and project configuration.
  @moduledoc false

  @default_region "us-central1"

  @enforce_keys [:api_key, :project_id, :model]
  defstruct @enforce_keys ++ [region: @default_region]

  @type t :: %__MODULE__{
          api_key: String.t(),
          project_id: String.t(),
          model: String.t(),
          region: String.t()
        }

  use Codicil.LLM
  use Codicil.Embeddings

  alias Codicil.Embeddings.Result

  # LLM Implementation

  @impl Codicil.LLM
  def generate_text(
        %__MODULE__{api_key: api_key, project_id: project_id, model: model, region: region},
        prompt,
        opts
      ) do
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)

    body = %{
      contents: [
        %{
          role: "user",
          parts: [%{text: prompt}]
        }
      ],
      generationConfig: %{
        temperature: temperature,
        maxOutputTokens: max_tokens
      }
    }

    case make_generate_request(api_key, project_id, model, region, body) do
      {:ok, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}}]}} ->
        {:ok, text}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_generate_request(api_key, project_id, model, region, body) do
    url =
      "https://#{region}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{region}/publishers/google/models/#{model}:generateContent"

    case Req.post(
           url,
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: response}} when status >= 200 and status <= 299 ->
        # Log token usage
        if usage_metadata = Map.get(response, "usageMetadata") do
          prompt_tokens = Map.get(usage_metadata, "promptTokenCount", 0)
          candidates_tokens = Map.get(usage_metadata, "candidatesTokenCount", 0)

          total_tokens =
            Map.get(usage_metadata, "totalTokenCount", prompt_tokens + candidates_tokens)

          require Logger

          Logger.info(
            "Google LLM call - Model: #{model}, Input tokens: #{prompt_tokens}, Output tokens: #{candidates_tokens}, Total: #{total_tokens}"
          )
        end

        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        error_message = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Embeddings Implementation

  @impl Codicil.Embeddings
  def embed(
        %__MODULE__{
          api_key: api_key,
          project_id: project_id,
          model: model,
          region: region
        },
        text,
        _opts
      ) do
    body = %{
      instances: [%{content: text}]
    }

    case make_embed_request(api_key, project_id, model, region, body) do
      {:ok, %{"predictions" => [%{"embeddings" => %{"values" => embedding}}]}} ->
        {:ok, %Result{embedding: embedding, dimensions: length(embedding)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Codicil.Embeddings
  def embed_batch(
        %__MODULE__{
          api_key: api_key,
          project_id: project_id,
          model: model,
          region: region
        },
        texts,
        _opts
      ) do
    body = %{
      instances: Enum.map(texts, fn text -> %{content: text} end)
    }

    case make_embed_request(api_key, project_id, model, region, body) do
      {:ok, %{"predictions" => predictions}} ->
        results =
          Enum.map(predictions, fn %{"embeddings" => %{"values" => embedding}} ->
            %Result{embedding: embedding, dimensions: length(embedding)}
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_embed_request(api_key, project_id, model, region, body) do
    url =
      "https://#{region}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{region}/publishers/google/models/#{model}:predict"

    case Req.post(
           url,
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: response}} when status >= 200 and status <= 299 ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        error_message = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
