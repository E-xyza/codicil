defmodule CodicilTest.Embeddings.Mock do
  @moduledoc """
  Mock Embeddings client for testing.

  Returns dummy embeddings without making API calls.

  ## Usage

      test "generates embeddings" do
        mock = %CodicilTest.Embeddings.Mock{test_pid: self()}

        result = Codicil.Embeddings.embed(mock, "test text")

        # Verify the mock was called
        assert_receive {:embeddings_embed, "test text", []}
        assert {:ok, %Codicil.Embeddings.Result{}} = result
      end

  If `test_pid` is nil, the mock operates silently without sending messages.
  """

  defstruct test_pid: nil

  @type t :: %__MODULE__{
          test_pid: pid() | nil
        }

  use Codicil.Embeddings

  alias Codicil.Embeddings.Result

  @impl Codicil.Embeddings
  def embed(%__MODULE__{test_pid: test_pid}, text, opts) do
    if test_pid, do: send(test_pid, {:embeddings_embed, text, opts})
    # Return a dummy 4-dimensional embedding
    {:ok, %Result{embedding: [0.1, 0.2, 0.3, 0.4], dimensions: 4}}
  end

  @impl Codicil.Embeddings
  def embed_batch(%__MODULE__{test_pid: test_pid}, texts, opts) do
    if test_pid, do: send(test_pid, {:embeddings_embed_batch, texts, opts})
    # Return dummy embeddings for each text
    results =
      Enum.map(texts, fn _ ->
        %Result{embedding: [0.1, 0.2, 0.3, 0.4], dimensions: 4}
      end)

    {:ok, results}
  end
end
