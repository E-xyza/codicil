defmodule CodicilTest.LLM.ErrorMock do
  @moduledoc """
  Mock LLM client that returns errors for testing error handling.
  """

  defstruct []

  @type t :: %__MODULE__{}

  use Codicil.LLM

  @impl Codicil.LLM
  def generate_text(_client, _prompt, _opts) do
    {:error, "API error"}
  end
end
