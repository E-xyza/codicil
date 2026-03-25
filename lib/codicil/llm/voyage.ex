defmodule Codicil.LLM.Voyage do
  # Voyage AI client for vector embeddings.
  #
  # Voyage AI provides embedding models that can be used with Anthropic's
  # Claude for retrieval-augmented generation (RAG) use cases.
  @moduledoc false

  @enforce_keys [:api_key, :model]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          api_key: String.t(),
          model: String.t()
        }

  use Codicil.Embeddings

  alias Codicil.Embeddings.Result

  @api_base_url "https://api.voyageai.com/v1"

  # Embeddings Implementation

  @impl Codicil.Embeddings
  def embed(%__MODULE__{api_key: api_key, model: model}, text, opts) do
    input_type = Keyword.get(opts, :input_type, "document")

    body = %{
      model: model,
      input: text,
      input_type: input_type
    }

    case make_embeddings_request(api_key, body) do
      {:ok, %{"data" => [%{"embedding" => embedding}]}} ->
        dimensions = length(embedding)
        {:ok, %Result{embedding: embedding, dimensions: dimensions}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Codicil.Embeddings
  def embed_batch(%__MODULE__{api_key: api_key, model: model}, texts, opts) do
    input_type = Keyword.get(opts, :input_type, "document")

    body = %{
      model: model,
      input: texts,
      input_type: input_type
    }

    case make_embeddings_request(api_key, body) do
      {:ok, %{"data" => embeddings_data}} ->
        results =
          Enum.map(embeddings_data, fn %{"embedding" => emb} ->
            dimensions = length(emb)
            %Result{embedding: emb, dimensions: dimensions}
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
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: response}} when status >= 200 and status <= 299 ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        error_message = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, %{status: status, body: body}} when is_map(body) ->
        error_message = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end
