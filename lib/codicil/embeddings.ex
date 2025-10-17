use Protoss

defprotocol Codicil.Embeddings do
  @moduledoc """
  Protocol for embedding generation across different providers.

  Embeddings convert text into vector representations for semantic search.
  """

  defmodule Result do
    @moduledoc """
    Result struct containing an embedding vector.
    """
    @type t :: %__MODULE__{
            embedding: [float()],
            dimensions: pos_integer()
          }

    defstruct [:embedding, :dimensions]
  end

  @doc """
  Generates an embedding for a single text string.

  ## Parameters
  - `client` - The embeddings client (Anthropic, Local, etc.)
  - `text` - The text to embed
  - `opts` - Optional parameters:
    - `:input_type` - "passage" for indexing, "query" for searching (default: "passage")

  ## Returns
  - `{:ok, %Result{}}` - The embedding result
  - `{:error, reason}` - Error information
  """
  @spec embed(t(), String.t(), keyword()) :: {:ok, Result.t()} | {:error, term()}
  def embed(client, text, opts \\ [])

  @doc """
  Generates embeddings for a batch of texts.

  ## Parameters
  - `client` - The embeddings client
  - `texts` - List of texts to embed
  - `opts` - Optional parameters (same as `embed/3`)

  ## Returns
  - `{:ok, [%Result{}]}` - List of embedding results
  - `{:error, reason}` - Error information
  """
  @spec embed_batch(t(), [String.t()], keyword()) :: {:ok, [Result.t()]} | {:error, term()}
  def embed_batch(client, texts, opts \\ [])
end
