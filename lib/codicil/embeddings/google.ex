defmodule Codicil.Embeddings.Google do
  @moduledoc """
  Google Vertex AI embeddings client.

  Supports text embeddings via Google's Vertex AI API.
  Requires Google Cloud credentials and project configuration.
  """

  @default_model "text-embedding-004"
  @default_region "us-central1"

  defstruct [
    :api_key,
    :project_id,
    model: @default_model,
    region: @default_region
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          project_id: String.t(),
          model: String.t(),
          region: String.t()
        }

  use Codicil.Embeddings

  alias Codicil.Embeddings.Result

  @impl Codicil.Embeddings
  def embed(%__MODULE__{api_key: api_key, project_id: project_id, model: model, region: region}, text, _opts) do
    body = %{
      instances: [%{content: text}]
    }

    case make_request(api_key, project_id, model, region, body) do
      {:ok, %{"predictions" => [%{"embeddings" => %{"values" => embedding}}]}} ->
        {:ok, %Result{embedding: embedding, dimensions: length(embedding)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Codicil.Embeddings
  def embed_batch(%__MODULE__{api_key: api_key, project_id: project_id, model: model, region: region}, texts, _opts) do
    body = %{
      instances: Enum.map(texts, fn text -> %{content: text} end)
    }

    case make_request(api_key, project_id, model, region, body) do
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

  defp make_request(api_key, project_id, model, region, body) do
    url = "https://#{region}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{region}/publishers/google/models/#{model}:predict"

    case Req.post(
           url,
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
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
