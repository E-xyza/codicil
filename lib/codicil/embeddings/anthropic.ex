defmodule Codicil.Embeddings.Anthropic do
  @moduledoc """
  Anthropic embeddings client using Voyage AI models.

  Anthropic provides embeddings through their Voyage AI partnership.
  Uses the voyage-3 model for high-quality semantic embeddings.
  """

  @default_model "voyage-3"

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

  @api_base_url "https://api.anthropic.com/v1"

  @impl Codicil.Embeddings
  def embed(%__MODULE__{api_key: api_key, model: model}, text, opts) do
    input_type = Keyword.get(opts, :input_type, "passage")

    body = %{
      model: model,
      input: text,
      input_type: input_type
    }

    case make_request(api_key, body) do
      {:ok, %{"embedding" => embedding, "dimensions" => dimensions}} ->
        {:ok, %Result{embedding: embedding, dimensions: dimensions}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Codicil.Embeddings
  def embed_batch(%__MODULE__{api_key: api_key, model: model}, texts, opts) do
    input_type = Keyword.get(opts, :input_type, "passage")

    body = %{
      model: model,
      inputs: texts,
      input_type: input_type
    }

    case make_request(api_key, body) do
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

  defp make_request(api_key, body) do
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
