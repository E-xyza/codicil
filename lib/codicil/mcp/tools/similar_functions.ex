defmodule Codicil.MCP.Tools.SimilarFunctions do
  @moduledoc """
  MCP tool for semantic function search using vector similarity and LLM validation.

  Finds functions semantically similar to a natural language description using:
  1. Vector similarity search (fast, broad recall)
  2. LLM validation (accurate, reranking)
  """

  alias Codicil.Functions
  alias Codicil.Embeddings
  alias Codicil.LLM
  alias Codicil.LLM.Validator

  @doc """
  Find functions semantically similar to a description.

  ## Parameters
  - `description` - Natural language description of desired functionality
  - `embeddings_client` - Embeddings client (optional, defaults to env var)
  - `llm_client` - LLM client for validation (optional, defaults to env var)
  - `limit` - Maximum results to return (default: 10)
  - `batch_size` - Functions to validate per LLM call (default: 20)
  - `vector_limit` - Functions to retrieve from vector search (default: 100)

  ## Returns
  - `{:ok, text}` with formatted list of matching functions
  - `{:error, reason}` if search fails

  ## Example
      iex> SimilarFunctions.call(%{"description" => "calculate sum of numbers"})
      {:ok, "Found 3 matching functions:\\n1. Math.Calculator.sum/1..."}
  """
  def call(%{"description" => description} = args) do
    limit = Map.get(args, "limit", 10)
    batch_size = Map.get(args, "batch_size", 20)
    vector_limit = Map.get(args, "vector_limit", 100)

    # Get clients from args or environment
    embeddings_client =
      case Map.get(args, "embeddings_client") do
        nil -> get_default_embeddings_client()
        client -> client
      end

    llm_client =
      case Map.get(args, "llm_client") do
        nil -> get_default_llm_client()
        client -> client
      end

    cond do
      is_nil(embeddings_client) ->
        {:error,
         "No embeddings client available. Set ANTHROPIC_API_KEY environment variable."}

      is_nil(llm_client) ->
        {:error,
         "No LLM client available. Set ANTHROPIC_API_KEY or OPENAI_API_KEY environment variable."}

      true ->
        search_similar_functions(
          embeddings_client,
          llm_client,
          description,
          limit,
          batch_size,
          vector_limit
        )
    end
  end

  def call(_args) do
    {:error, "Missing required parameter: description"}
  end

  defp search_similar_functions(
         embeddings_client,
         llm_client,
         description,
         limit,
         batch_size,
         vector_limit
       ) do
    # Step 1: Generate embedding for query description
    case Embeddings.embed(embeddings_client, description, input_type: "query") do
      {:ok, %Embeddings.Result{embedding: query_embedding}} ->
        # Step 2: Vector similarity search
        candidates = Functions.find_similar(query_embedding, limit: vector_limit)

        if Enum.empty?(candidates) do
          {:ok, "No functions with embeddings found. Run indexing first."}
        else
          # Convert Function structs to maps for validation
          candidate_maps =
            Enum.map(candidates, fn f ->
              %{
                id: f.id,
                name: f.name,
                module: f.module,
                path: f.path,
                line: f.line,
                summary: f.summary
              }
            end)

          # Step 3: LLM validation with early stopping for reranking
          validated =
            validate_with_early_stopping(llm_client, description, candidate_maps, batch_size)

          # Step 4: Sort by confidence and take top results
          matches =
            validated
            |> Enum.filter(& &1.matches)
            |> Enum.sort_by(& &1.confidence, :desc)
            |> Enum.take(limit)

          format_results(matches, description, candidate_maps, vector_limit)
        end

      {:error, reason} ->
        {:error, "Failed to generate query embedding: #{inspect(reason)}"}
    end
  end

  defp validate_with_early_stopping(llm_client, description, candidates, batch_size) do
    candidates
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce_while([], fn batch, acc ->
      case Validator.validate_batch(llm_client, description, batch) do
        {:ok, results} ->
          # Check if we hit a non-match (early stopping)
          has_non_match = Enum.any?(results, &(not &1.matches))

          if has_non_match do
            # Stop processing, return accumulated + current batch
            {:halt, acc ++ results}
          else
            # Continue to next batch
            {:cont, acc ++ results}
          end

        {:error, _reason} ->
          # On error, continue with empty results for this batch
          {:cont, acc}
      end
    end)
  end

  defp format_results(matches, description, all_candidates, vector_limit)
       when length(matches) > 0 do
    count = length(matches)
    total_scanned = length(all_candidates)

    match_list =
      matches
      |> Enum.with_index(1)
      |> Enum.map(fn {match, idx} ->
        # Find the original function data
        func =
          Enum.find(all_candidates, fn c -> c.id == match.function_id end) ||
            %{name: "unknown", module: "unknown", path: "unknown", line: 0, summary: ""}

        confidence_pct = if match.confidence, do: round(match.confidence * 100), else: "?"

        """
        #{idx}. #{func.module}.#{func.name} (#{confidence_pct}% match)
           Location: #{func.path}:#{func.line}
           Summary: #{func.summary}
           Reasoning: #{match.reasoning || "No reasoning provided"}
        """
      end)
      |> Enum.join("\n")

    result = """
    Found #{count} matching function(s) for "#{description}" (vector search: #{vector_limit}, validated: #{total_scanned}):

    #{match_list}
    """

    {:ok, result}
  end

  defp format_results([], description, all_candidates, vector_limit) do
    {:ok,
     "No matching functions found for \"#{description}\" (vector search: #{vector_limit}, validated: #{length(all_candidates)})."}
  end

  defp get_default_embeddings_client do
    cond do
      api_key = System.get_env("ANTHROPIC_API_KEY") ->
        %Codicil.LLM.Anthropic{api_key: api_key}

      api_key = System.get_env("OPENAI_API_KEY") ->
        %Codicil.LLM.OpenAI{api_key: api_key}

      api_key = System.get_env("COHERE_API_KEY") ->
        %Codicil.LLM.Cohere{api_key: api_key}

      true ->
        case {System.get_env("GOOGLE_API_KEY"), System.get_env("GOOGLE_PROJECT_ID")} do
          {api_key, project_id} when is_binary(api_key) and is_binary(project_id) ->
            %Codicil.LLM.Google{api_key: api_key, project_id: project_id}

          _ ->
            nil
        end
    end
  end

  defp get_default_llm_client do
    cond do
      api_key = System.get_env("ANTHROPIC_API_KEY") ->
        %LLM.Anthropic{api_key: api_key}

      api_key = System.get_env("OPENAI_API_KEY") ->
        %LLM.OpenAI{api_key: api_key}

      api_key = System.get_env("COHERE_API_KEY") ->
        %LLM.Cohere{api_key: api_key}

      true ->
        case {System.get_env("GOOGLE_API_KEY"), System.get_env("GOOGLE_PROJECT_ID")} do
          {api_key, project_id} when is_binary(api_key) and is_binary(project_id) ->
            %LLM.Google{api_key: api_key, project_id: project_id}

          _ ->
            nil
        end
    end
  end
end
