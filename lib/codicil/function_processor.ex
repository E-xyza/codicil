defmodule Codicil.FunctionProcessor do
  # Processes functions to generate summaries and embeddings.
  #
  # Takes a function database record and LLM/embeddings clients,
  # generates summaries and embeddings, and updates the database
  # incrementally after each step.
  @moduledoc false

  alias Codicil.Db.Function
  alias Codicil.Functions
  alias Codicil.LLM.Summarizer
  alias Codicil.Embeddings

  @doc """
  Processes a function to generate summary and embedding.

  Takes a Function struct from the database and generates:
  1. Summary for exported functions or functions with docs (if not already present)
  2. Embedding from the summary (if not already present)

  Updates the function record in the database after each step.
  Skips processing if summary and embedding already exist.
  """
  @spec process(Function.t(), llm_client :: module(), embeddings_client :: module()) :: :ok
  def process(%Function{} = function, llm_client, embeddings_client) do
    function
    |> generate_summary_if_needed(llm_client)
    |> generate_embedding_if_needed(embeddings_client)

    :ok
  end

  defp generate_summary_if_needed(%Function{summary: summary} = function, _llm_client)
       when is_binary(summary) do
    # Summary already exists, skip
    function
  end

  defp generate_summary_if_needed(%Function{} = function, llm_client) do
    # Determine if we should generate summary:
    # - All exported (public) functions
    # - Private functions with documentation
    should_summarize = function.exported or has_docs?(function)

    if should_summarize do
      # Build function_info map for Summarizer
      function_info = %{
        name: function.name,
        module: function.module,
        path: function.path,
        docs: function.docs,
        code: function.code,
        exported: function.exported
      }

      case Summarizer.summarize_function(llm_client, function_info) do
        {:ok, %{summary: summary}} ->
          # Update database immediately with summary
          {:ok, updated} = Functions.update(function, %{summary: summary})
          updated

        {:error, _reason} ->
          function
      end
    else
      function
    end
  end

  defp generate_embedding_if_needed(
         %Function{embedding: embedding} = function,
         _embeddings_client
       )
       when is_binary(embedding) do
    # Embedding already exists, skip
    function
  end

  defp generate_embedding_if_needed(%Function{summary: nil} = function, _embeddings_client) do
    # No summary available, cannot generate embedding
    function
  end

  defp generate_embedding_if_needed(%Function{summary: summary} = function, embeddings_client)
       when is_binary(summary) do
    case Embeddings.embed(embeddings_client, summary, input_type: "passage") do
      {:ok, %{embedding: embedding}} ->
        # Convert to binary format for storage
        embedding_binary =
          embedding
          |> Enum.map(&<<&1::float-32-native>>)
          |> IO.iodata_to_binary()

        # Update database immediately with embedding
        {:ok, updated} = Functions.update(function, %{embedding: embedding_binary})
        updated

      {:error, _reason} ->
        function
    end
  end

  defp has_docs?(%Function{docs: nil}), do: false
  defp has_docs?(%Function{docs: ""}), do: false
  defp has_docs?(%Function{docs: docs}) when is_binary(docs), do: true
end
