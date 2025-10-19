defmodule Codicil.RetirementTest do
  use ExUnit.Case, async: false

  alias Codicil.Functions
  alias Codicil.Db.Repo

  setup do
    # Start a sandbox transaction for isolated testing
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Allow background processes (tracer GenServers) to use the sandbox
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    Process.sleep(100)

    # Enable tracer for this test
    Code.put_compiler_option(:tracers, [Codicil.Tracer])

    on_exit(fn ->
      # Disable tracer after test
      Code.put_compiler_option(:tracers, [])
    end)

    :ok
  end

  # Helper to clean up module and its beam file
  defp cleanup_module(module) do
    :code.purge(module)
    :code.delete(module)

    # Delete beam file if it exists
    beam_dir = Path.join([File.cwd!(), "test", "_support", "beamfiles"])
    beam_file = Path.join(beam_dir, "#{module}.beam")
    File.rm(beam_file)
  end

  describe "function retirement" do
    test "removes functions that no longer exist after recompilation" do
      # Manually insert a stale function that doesn't exist in the source
      test_module_path = Path.join(__DIR__, "tracer_examples/retirement_test_module.ex")

      {:ok, _stale_function} =
        Functions.upsert(%{
          name: :stale_function,
          module: RetirementTestModule,
          arity: 1,
          exported: true,
          path: test_module_path,
          line: 99,
          checksum: "stale123"
        })

      # Verify stale function exists before compilation
      assert Functions.get_by_mfa({RetirementTestModule, :stale_function, 1})

      # Compile the module (which only has active_function, not stale_function)
      [{module, _}] = Code.compile_file(test_module_path)

      # Give the background task time to complete
      Process.sleep(100)

      # Verify active_function exists
      assert Functions.get_by_mfa({RetirementTestModule, :active_function, 1})

      # Verify stale_function was removed
      refute Functions.get_by_mfa({RetirementTestModule, :stale_function, 1})

      # Clean up
      cleanup_module(module)
    end
  end
end
