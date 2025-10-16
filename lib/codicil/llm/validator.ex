defmodule Codicil.LLM.Validator do
  @moduledoc """
  LLM-based validation of semantic search results.

  Uses an LLM to validate whether candidate functions truly match a semantic query,
  enabling early stopping when non-matches are detected.
  """

  alias Codicil.LLM

  defmodule Result do
    @moduledoc """
    Result of function validation.
    """
    @type t :: %__MODULE__{
            function_id: integer(),
            matches: boolean(),
            confidence: float() | nil,
            reasoning: String.t() | nil
          }

    defstruct [:function_id, :matches, :confidence, :reasoning]
  end

  @doc """
  Validates a batch of functions against a semantic query using an LLM.

  ## Parameters
  - `llm_client` - An LLM client (Claude, OpenAI, etc.)
  - `query` - The semantic search query
  - `functions` - List of function maps containing:
    - `:id` - Function ID
    - `:name` - Function name
    - `:module` - Module name
    - `:summary` - Function summary
  - `opts` - Optional parameters:
    - `:batch_size` - Functions to validate per API call (default: 20)
    - `:max_tokens` - Max tokens for response (default: 2000)

  ## Returns
  - `{:ok, [%Result{}]}` - List of validation results
  - `{:error, reason}` - Error information

  ## Example
      iex> functions = [
      ...>   %{id: 1, name: "calculate_total", module: "Math", summary: "Sums numbers"},
      ...>   %{id: 2, name: "format_string", module: "Text", summary: "Formats text"}
      ...> ]
      iex> Validator.validate_batch(llm_client, "sum calculation", functions)
      {:ok, [
        %Result{function_id: 1, matches: true, confidence: 0.95},
        %Result{function_id: 2, matches: false, confidence: 0.10}
      ]}
  """
  @spec validate_batch(LLM.t(), String.t(), [map()], keyword()) ::
          {:ok, [Result.t()]} | {:error, term()}
  def validate_batch(llm_client, query, functions, opts \\ []) do
    max_tokens = Keyword.get(opts, :max_tokens, 2000)

    prompt = build_validation_prompt(query, functions)

    system_message = """
    You are a code search relevance expert. Evaluate whether each function matches the user's query.

    For each function, provide:
    1. A boolean "matches" (true/false)
    2. A "confidence" score (0.0 to 1.0)
    3. Brief "reasoning" explaining the decision

    Respond ONLY with valid JSON in this exact format:
    {
      "validations": [
        {"function_id": 1, "matches": true, "confidence": 0.95, "reasoning": "..."},
        {"function_id": 2, "matches": false, "confidence": 0.10, "reasoning": "..."}
      ]
    }

    Be strict: only mark as matching if the function clearly implements or relates to the query.
    """

    case LLM.generate_text(llm_client, prompt,
           max_tokens: max_tokens,
           system: system_message,
           temperature: 0.1
         ) do
      {:ok, response_text} ->
        parse_validation_response(response_text)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_validation_prompt(query, functions) do
    function_list =
      functions
      |> Enum.map(fn func ->
        """
        Function ID: #{func.id}
        Name: #{func.module}.#{func.name}
        Summary: #{func.summary || "No summary available"}
        """
      end)
      |> Enum.join("\n---\n")

    """
    Query: "#{query}"

    Evaluate these functions:

    #{function_list}

    Provide validation results in JSON format.
    """
  end

  defp parse_validation_response(response_text) do
    # Clean up the response (remove markdown code blocks if present)
    clean_json =
      response_text
      |> String.trim()
      |> String.replace(~r/^```json\s*/m, "")
      |> String.replace(~r/```\s*$/m, "")
      |> String.trim()

    case Jason.decode(clean_json) do
      {:ok, %{"validations" => validations}} when is_list(validations) ->
        results =
          Enum.map(validations, fn v ->
            %Result{
              function_id: Map.get(v, "function_id"),
              matches: Map.get(v, "matches", false),
              confidence: Map.get(v, "confidence"),
              reasoning: Map.get(v, "reasoning")
            }
          end)

        {:ok, results}

      {:ok, _} ->
        {:error, "Invalid response format: missing 'validations' array"}

      {:error, reason} ->
        {:error, "Failed to parse JSON response: #{inspect(reason)}"}
    end
  end
end
