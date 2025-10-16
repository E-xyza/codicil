defprotocol Codicil.LLM do
  @moduledoc """
  Protocol for LLM client implementations.

  Provides a unified interface for generating text completions across different
  LLM providers (Claude, OpenAI, Grok, etc.).
  """

  @doc """
  Generates a text completion from the given prompt.

  ## Parameters
  - `client` - The LLM client struct (Claude, OpenAI, or Grok)
  - `prompt` - The text prompt to send to the LLM
  - `opts` - Optional parameters:
    - `:max_tokens` - Maximum tokens to generate (default: 1024)
    - `:temperature` - Sampling temperature 0.0-1.0 (default: 0.7)
    - `:system` - System message/instructions (optional)

  ## Returns
  - `{:ok, text}` - The generated text response
  - `{:error, reason}` - Error information
  """
  @spec generate_text(t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_text(client, prompt, opts \\ [])
end
