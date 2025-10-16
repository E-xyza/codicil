defmodule Codicil.Embeddings.Cohere do
  @moduledoc """
  Cohere embeddings client.

  Supports text embeddings via Cohere's API.
  """

  @default_model "embed-english-v3.0"
  @api_base_url "https://api.cohere.ai/v1"

  defstruct [
    :api_key,
    model: @default_model
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          model: String.t()
        }

  use Codicil.Embeddings

  alias Codicil.Embeddings.Result

  @impl Codicil.Embeddings
  def embed(%__MODULE__{api_key: api_key, model: model}, text, opts) do
    input_type = Keyword.get(opts, :input_type, "search_document")

    body = %{
      model: model,
      texts: [text],
      input_type: input_type
    }

    case make_request(api_key, body) do
      {:ok, %{"embeddings" => [embedding]}} ->
        {:ok, %Result{embedding: embedding, dimensions: length(embedding)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Codicil.Embeddings
  def embed_batch(%__MODULE__{api_key: api_key, model: model}, texts, opts) do
    input_type = Keyword.get(opts, :input_type, "search_document")

    body = %{
      model: model,
      texts: texts,
      input_type: input_type
    }

    case make_request(api_key, body) do
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

  defp make_request(api_key, body) do
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
