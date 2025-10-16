defmodule Codicil.LLM.ValidatorTest do
  use ExUnit.Case, async: true

  alias Codicil.LLM.Validator

  describe "validate_batch/4" do
    test "result struct contains validation info" do
      result = %Validator.Result{
        function_id: 123,
        matches: true,
        confidence: 0.95,
        reasoning: "Function clearly implements the requested behavior"
      }

      assert result.function_id == 123
      assert result.matches
      assert result.confidence == 0.95
      assert result.reasoning == "Function clearly implements the requested behavior"
    end
  end
end
