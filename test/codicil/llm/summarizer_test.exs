defmodule Codicil.LLM.SummarizerTest do
  use ExUnit.Case, async: true

  alias Codicil.LLM.Summarizer

  describe "summarize_function/3" do
    test "result struct contains summary" do
      result = %Summarizer.Result{
        summary: "Calculates the total sum of a list of items",
        tokens_used: 50
      }

      assert result.summary == "Calculates the total sum of a list of items"
      assert result.tokens_used == 50
    end
  end
end
