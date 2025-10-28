defmodule Codicil.FunctionProcessor do
  # Processes functions to generate summaries and embeddings.
  #
  # Takes function metadata and LLM/embeddings clients, generates summaries
  # and embeddings, then updates the database.
  @moduledoc false

  alias Codicil.Functions
  alias Codicil.LLM.Summarizer
  alias Codicil.Embeddings

  @doc """
  Processes a function to generate summary and embedding.

  Takes function_info map with:
  - id: Function database ID
  - exported: Whether function is exported
  - docs: Function documentation (may be nil)
  - code: Function source code
  - name, module, path: Metadata for LLM prompts

  Generates:
  1. Summary for exported functions or functions with docs
  2. Embedding from the summary

  Updates the function record in the database with results.
  """
  def process(function_info, llm_client, embeddings_client) do
    # Determine if we should generate summary:
    # - All exported (public) functions
    # - Private functions with documentation
    should_summarize =
      Map.get(function_info, :exported, false) or has_docs?(function_info)

    # Generate summary if appropriate
    summary =
      if should_summarize do
        case Summarizer.summarize_function(llm_client, function_info) do
          {:ok, %{summary: summary}} -> summary
          {:error, _reason} -> nil
        end
      else
        nil
      end

    # Generate embedding if we have summary
    embedding =
      if summary do
        case Embeddings.embed(embeddings_client, summary, input_type: "passage") do
          {:ok, %{embedding: embedding}} ->
            # Convert to binary format for storage
            embedding
            |> Enum.map(&<<&1::float-32-native>>)
            |> IO.iodata_to_binary()

          {:error, _reason} ->
            nil
        end
      else
        nil
      end

    # Update function record with results
    case Functions.get(function_info.id) do
      nil ->
        :ok

      function ->
        attrs =
          %{}
          |> maybe_put(:summary, summary)
          |> maybe_put(:embedding, embedding)

        if map_size(attrs) > 0 do
          Functions.update(function, attrs)
        end
    end

    :ok
  end

  defp has_docs?(function_info) do
    case Map.get(function_info, :docs) do
      nil -> false
      "" -> false
      docs when is_binary(docs) -> true
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
