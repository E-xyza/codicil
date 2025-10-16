defmodule Codicil.LLM.Claude do
  @moduledoc """
  Backwards compatibility alias for Codicil.LLM.Anthropic.

  Use `Codicil.LLM.Anthropic` instead. This module will be removed in a future version.
  """

  defstruct [
    :api_key,
    model: "claude-3-5-sonnet-20241022"
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          model: String.t()
        }

  use Codicil.LLM

  @impl Codicil.LLM
  def generate_text(%__MODULE__{api_key: api_key, model: model}, prompt, opts) do
    # Convert to Anthropic struct
    anthropic = %Codicil.LLM.Anthropic{
      api_key: api_key,
      llm_model: model
    }

    Codicil.LLM.Anthropic.generate_text(anthropic, prompt, opts)
  end
end
