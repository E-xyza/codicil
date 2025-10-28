defmodule Codicil.FunctionProcessorTest do
  use ExUnit.Case, async: false

  alias Codicil.FunctionProcessor
  alias Codicil.Functions
  alias Codicil.Db.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "process/3" do
    test "generates summary and embedding for exported function without docs" do
      # Create function in database
      {:ok, function} =
        Functions.create(%{
          name: "test_function",
          module: "TestModule",
          arity: 1,
          exported: true,
          path: "/test.ex",
          line: 1,
          checksum: "abc123",
          code: "def test_function(x), do: x + 1"
        })

      # Create mock clients
      llm_client = %CodicilTest.LLM.Mock{test_pid: self()}
      embeddings_client = %CodicilTest.Embeddings.Mock{test_pid: self()}

      # Process function (now takes Function struct)
      :ok = FunctionProcessor.process(function, llm_client, embeddings_client)

      # Verify LLM was called for summary
      assert_receive {:llm_generate_text, _prompt, _opts}

      # Verify embeddings was called
      assert_receive {:embeddings_embed, _text, _opts}

      # Verify function was updated
      updated = Functions.get(function.id)
      assert updated.summary == "mock response"
      assert is_binary(updated.embedding)
    end

    test "generates summary and embedding for private function with docs" do
      # Create function in database
      {:ok, function} =
        Functions.create(%{
          name: "helper",
          module: "TestModule",
          arity: 1,
          exported: false,
          path: "/test.ex",
          line: 5,
          checksum: "def456",
          docs: "Helper function that does something useful",
          code: "defp helper(x), do: x * 2"
        })

      # Create mock clients
      llm_client = %CodicilTest.LLM.Mock{test_pid: self()}
      embeddings_client = %CodicilTest.Embeddings.Mock{test_pid: self()}

      # Process function (now takes Function struct)
      :ok = FunctionProcessor.process(function, llm_client, embeddings_client)

      # Verify LLM was called for summary
      assert_receive {:llm_generate_text, _prompt, _opts}

      # Verify embeddings was called
      assert_receive {:embeddings_embed, _text, _opts}

      # Verify function was updated
      updated = Functions.get(function.id)
      assert updated.summary == "mock response"
      assert is_binary(updated.embedding)
    end

    test "skips summary generation for private function without docs" do
      # Create function in database
      {:ok, function} =
        Functions.create(%{
          name: "internal_helper",
          module: "TestModule",
          arity: 0,
          exported: false,
          path: "/test.ex",
          line: 10,
          checksum: "ghi789",
          docs: nil,
          code: "defp internal_helper, do: :ok"
        })

      # Create mock clients
      llm_client = %CodicilTest.LLM.Mock{test_pid: self()}
      embeddings_client = %CodicilTest.Embeddings.Mock{test_pid: self()}

      # Process function (now takes Function struct)
      :ok = FunctionProcessor.process(function, llm_client, embeddings_client)

      # Verify LLM was NOT called
      refute_receive {:llm_generate_text, _prompt, _opts}, 100

      # Verify embeddings was NOT called
      refute_receive {:embeddings_embed, _text, _opts}, 100

      # Verify function was not updated with summary
      updated = Functions.get(function.id)
      assert is_nil(updated.summary)
      assert is_nil(updated.embedding)
    end

    test "handles function deleted during processing" do
      # Create function in database
      {:ok, function} =
        Functions.create(%{
          name: "will_be_deleted",
          module: "TestModule",
          arity: 0,
          exported: true,
          path: "/test.ex",
          line: 1,
          checksum: "del123",
          code: "def will_be_deleted, do: :ok"
        })

      # Delete the function before processing
      Functions.delete(function)

      # Create mock clients
      llm_client = %CodicilTest.LLM.Mock{test_pid: self()}
      embeddings_client = %CodicilTest.Embeddings.Mock{test_pid: self()}

      # Processing will fail when trying to update the deleted function
      # For now, this will raise - in the future we might handle it gracefully
      assert_raise Ecto.StaleEntryError, fn ->
        FunctionProcessor.process(function, llm_client, embeddings_client)
      end
    end

    test "skips processing if function already has summary and embedding" do
      # Create function with existing summary and embedding
      {:ok, function} =
        Functions.create(%{
          name: "already_processed",
          module: "TestModule",
          arity: 1,
          exported: true,
          path: "/test.ex",
          line: 1,
          checksum: "xyz123",
          code: "def already_processed(x), do: x",
          summary: "Existing summary",
          embedding: <<1, 2, 3, 4>>
        })

      # Create mock clients
      llm_client = %CodicilTest.LLM.Mock{test_pid: self()}
      embeddings_client = %CodicilTest.Embeddings.Mock{test_pid: self()}

      # Process function (now takes Function struct)
      :ok = FunctionProcessor.process(function, llm_client, embeddings_client)

      # Should NOT call LLM when summary already exists
      refute_receive {:llm_generate_text, _prompt, _opts}, 100

      # Should NOT call embeddings when embedding already exists
      refute_receive {:embeddings_embed, _text, _opts}, 100

      # Verify function was not updated (still has original summary/embedding)
      updated = Functions.get(function.id)
      assert updated.summary == "Existing summary"
      assert updated.embedding == <<1, 2, 3, 4>>
    end

    test "handles LLM errors gracefully" do
      # Create function in database
      {:ok, function} =
        Functions.create(%{
          name: "test_error",
          module: "TestModule",
          arity: 0,
          exported: true,
          path: "/test.ex",
          line: 1,
          checksum: "err123",
          code: "def test_error, do: :ok"
        })

      # Create mock client that returns error
      llm_client = %CodicilTest.LLM.ErrorMock{}
      embeddings_client = %CodicilTest.Embeddings.Mock{test_pid: self()}

      # Process function (now takes Function struct)
      # Should not crash
      :ok = FunctionProcessor.process(function, llm_client, embeddings_client)

      # Function should not be updated with nil summary
      updated = Functions.get(function.id)
      assert is_nil(updated.summary)
      assert is_nil(updated.embedding)
    end
  end
end
