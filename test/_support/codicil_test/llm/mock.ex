defmodule CodicilTest.LLM.Mock do
  @moduledoc """
  Mock LLM client for testing.

  This mock client sends messages to a test process instead of making actual API calls.
  The test process can respond with expected results or verify that calls were made.

  ## Usage

      test "calls LLM with correct prompt" do
        mock = %CodicilTest.LLM.Mock{test_pid: self()}

        # The mock will send a message to self() when called
        result = Codicil.LLM.generate(mock, "test prompt")

        # Verify the call was made
        assert_receive {:llm_generate, "test prompt"}

        # Respond with mock result
        send(mock.test_pid, {:llm_result, {:ok, "mock response"}})
      end
  """

  @enforce_keys [:test_pid]
  defstruct [:test_pid]

  @type t :: %__MODULE__{
          test_pid: pid()
        }
end
