defmodule Codicil.LLM.Summarizer do
  # Function summarization using LLMs.
  #
  # Generates concise, semantic summaries of Elixir functions for embedding
  # and semantic search purposes.
  @moduledoc false

  alias Codicil.LLM

  defmodule Result do
    # Result of a function summarization.
    @moduledoc false
    @type t :: %__MODULE__{
            summary: String.t(),
            tokens_used: non_neg_integer() | nil
          }

    defstruct [:summary, :tokens_used]
  end

  @doc """
  Generates a summary of a function using an LLM.

  ## Parameters
  - `llm_client` - An LLM client (Claude, OpenAI, etc.)
  - `function_info` - Map containing:
    - `:name` - Function name
    - `:module` - Module name
    - `:docs` - Function documentation (optional)
    - `:code` - Function source code (optional)
  - `opts` - Optional parameters:
    - `:max_tokens` - Max tokens for summary (default: 150)

  ## Returns
  - `{:ok, %Result{}}` - The generated summary
  - `{:error, reason}` - Error information
  """
  @spec summarize_function(LLM.t(), map(), keyword()) :: {:ok, Result.t()} | {:error, term()}
  def summarize_function(llm_client, function_info, opts \\ []) do
    max_tokens = Keyword.get(opts, :max_tokens, 150)

    prompt = build_summary_prompt(function_info)

    system_message = """
    You are a code documentation expert. Generate concise, accurate summaries of Elixir functions.
    The summary should:
    - Be 1-2 sentences maximum
    - Focus on what the function does, not how it does it
    - Use present tense (e.g., "Calculates...", "Returns...", "Checks...")
    - Be specific and meaningful for semantic search
    """

    case LLM.generate_text(llm_client, prompt,
           max_tokens: max_tokens,
           system: system_message,
           temperature: 0.3
         ) do
      {:ok, summary} ->
        # Clean up the summary (remove quotes, trim whitespace)
        clean_summary =
          summary
          |> String.trim()
          |> String.trim("\"")
          |> String.trim()

        {:ok, %Result{summary: clean_summary, tokens_used: nil}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_summary_prompt(function_info) do
    name = Map.get(function_info, :name, "unknown")
    module = Map.get(function_info, :module, "")
    docs = Map.get(function_info, :docs)
    code = Map.get(function_info, :code)

    parts = [
      "Function: #{module}.#{name}",
      if(docs, do: "Documentation:\n#{docs}", else: nil),
      if(code, do: "Code:\n```elixir\n#{code}\n```", else: nil),
      "\nGenerate a concise summary (1-2 sentences):"
    ]

    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end
end
