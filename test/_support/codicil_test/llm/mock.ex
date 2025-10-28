defmodule CodicilTest.LLM.Mock do
  @moduledoc """
  Mock LLM client for testing.

  This mock returns immediate responses without making API calls,
  allowing tests to verify behavior without network dependencies.

  ## Usage

      test "calls LLM with correct prompt" do
        mock = %CodicilTest.LLM.Mock{test_pid: self()}

        result = Codicil.LLM.generate_text(mock, "test prompt")

        # Verify the mock was called
        assert_receive {:llm_generate_text, "test prompt", []}
        assert result == {:ok, "mock response"}
      end

  If `test_pid` is nil, the mock operates silently without sending messages.
  """

  defstruct test_pid: nil

  @type t :: %__MODULE__{
          test_pid: pid() | nil
        }

  use Codicil.LLM

  @impl Codicil.LLM
  def generate_text(%__MODULE__{test_pid: test_pid}, prompt, opts) do
    if test_pid, do: send(test_pid, {:llm_generate_text, prompt, opts})
    {:ok, "mock response"}
  end
end
