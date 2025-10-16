defmodule Codicil.MCP.Tools.SimilarFunctions do
  @moduledoc """
  MCP tool for semantic function search using LLM validation.

  Finds functions semantically similar to a natural language description.
  Currently uses LLM validation without vector embeddings (future enhancement).
  """

  alias Codicil.Db.Repo
  alias Codicil.Db.Function
  alias Codicil.LLM
  alias Codicil.LLM.Validator

  @doc """
  Find functions semantically similar to a description.

  ## Parameters
  - `description` - Natural language description of desired functionality
  - `llm_client` - LLM client for validation (optional, defaults to env var)
  - `limit` - Maximum results to return (default: 10)
  - `batch_size` - Functions to validate per LLM call (default: 20)

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

    # Get LLM client from args or environment
    llm_client =
      case Map.get(args, "llm_client") do
        nil -> get_default_llm_client()
        client -> client
      end

    if is_nil(llm_client) do
      {:error,
       "No LLM client available. Set ANTHROPIC_API_KEY or OPENAI_API_KEY environment variable."}
    else
      search_similar_functions(llm_client, description, limit, batch_size)
    end
  end

  def call(_args) do
    {:error, "Missing required parameter: description"}
  end

  defp search_similar_functions(llm_client, description, limit, batch_size) do
    import Ecto.Query

    # TODO: When sqlite-vec is integrated, use vector similarity search
    # For now, fetch all functions with summaries and use LLM validation
    candidates =
      from(f in Function,
        where: not is_nil(f.summary) and f.summary != "",
        select: %{
          id: f.id,
          name: f.name,
          module: f.module,
          path: f.path,
          line: f.line,
          summary: f.summary
        }
      )
      |> Repo.all()

    if Enum.empty?(candidates) do
      {:ok, "No functions with summaries found. Run indexing first."}
    else
      # Validate candidates in batches with early stopping
      validated = validate_with_early_stopping(llm_client, description, candidates, batch_size)

      # Sort by confidence and take top results
      matches =
        validated
        |> Enum.filter(& &1.matches)
        |> Enum.sort_by(& &1.confidence, :desc)
        |> Enum.take(limit)

      format_results(matches, description, candidates)
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

  defp format_results(matches, description, all_candidates) when length(matches) > 0 do
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
    Found #{count} matching function(s) for "#{description}" (scanned #{total_scanned} total):

    #{match_list}
    """

    {:ok, result}
  end

  defp format_results([], description, all_candidates) do
    {:ok,
     "No matching functions found for \"#{description}\" (scanned #{length(all_candidates)} functions)."}
  end

  defp get_default_llm_client do
    cond do
      api_key = System.get_env("ANTHROPIC_API_KEY") ->
        %LLM.Claude{api_key: api_key}

      api_key = System.get_env("OPENAI_API_KEY") ->
        %LLM.OpenAI{api_key: api_key, model: "gpt-4"}

      true ->
        nil
    end
  end
end
