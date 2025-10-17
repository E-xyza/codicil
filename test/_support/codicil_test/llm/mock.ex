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
  """

  @enforce_keys [:test_pid]
  defstruct [:test_pid]

  @type t :: %__MODULE__{
          test_pid: pid()
        }

  use Codicil.LLM

  @impl Codicil.LLM
  def generate_text(%__MODULE__{test_pid: test_pid}, prompt, opts) do
    send(test_pid, {:llm_generate_text, prompt, opts})
    {:ok, "mock response"}
  end
end
