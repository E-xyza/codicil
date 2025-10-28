defmodule Codicil.SourcerorTest do
  use ExUnit.Case, async: false

  alias Codicil.Functions
  alias Codicil.Db.Repo

  @test_file Path.join(__DIR__, "tracer_examples/sourceror_test_module.ex")

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Allow background processes (tracer GenServers) to use the sandbox
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    # Start RateLimiter with mock clients
    start_supervised!(
      {Codicil.RateLimiter,
       llm_client: %CodicilTest.LLM.Mock{test_pid: self()},
       embeddings_client: %CodicilTest.Embeddings.Mock{test_pid: self()}}
    )

    # Enable tracer for compilation
    Code.put_compiler_option(:tracers, [Codicil.Tracer])

    # Compile the test module
    [{module, _}] = Code.compile_file(@test_file)

    # Give the background task time to complete (including async doc updates)
    Process.sleep(200)

    # Disable tracer after compilation
    Code.put_compiler_option(:tracers, [])

    on_exit(fn ->
      :code.purge(module)
      :code.delete(module)

      # Delete beam file to avoid redefine warnings
      beam_dir = Path.join([File.cwd!(), "test", "_support", "beamfiles"])
      beam_file = Path.join(beam_dir, "#{module}.beam")
      File.rm(beam_file)
    end)

    :ok
  end

  describe "documentation extraction" do
    test "extracts public function with @doc attribute" do
      assert function = Functions.get_by_mfa({SourcerorTestModule, :public_with_docstring, 1})

      # Should have the @doc string
      assert function.docs == "This is a public function with a docstring"
      assert function.exported
    end

    test "public function with no docstring has nil docs" do
      assert function = Functions.get_by_mfa({SourcerorTestModule, :public_no_docstring, 1})

      # Should have nil docs
      assert function.docs == nil
      assert function.exported
    end
  end

  describe "code extraction" do
    test "stores function source code" do
      assert function = Functions.get_by_mfa({SourcerorTestModule, :public_with_docstring, 1})

      # Should have the function source code (includes the call to avoid unused warning)
      assert function.code ==
               "def public_with_docstring(x) do\n  # Call private function to avoid unused warning\n  _ = private_with_comment(x)\n  x * 2\nend"
    end

    test "stores code with internal comments" do
      assert function =
               Functions.get_by_mfa({SourcerorTestModule, :public_with_first_line_comment, 1})

      # Should include the internal comment
      assert function.code ==
               "def public_with_first_line_comment(x) do\n  # This is a first line comment\n  x / 2\nend"
    end
  end
end
