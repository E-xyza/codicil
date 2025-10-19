defmodule Codicil.FileWatcherTest do
  use ExUnit.Case, async: false

  alias Codicil.Functions
  alias Codicil.Modules
  alias Codicil.Db.Repo

  setup do
    # Start a sandbox transaction for isolated testing
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Allow background processes (file watcher) to use the sandbox
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

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

  describe "module retirement on file deletion" do
    test "removes module and its functions when source file is deleted" do
      # Create a temporary module file in test directory
      test_dir = Path.join([File.cwd!(), "test", "_support", "file_watcher_test"])
      File.mkdir_p!(test_dir)

      test_module_path = Path.join(test_dir, "file_watcher_test_module.ex")

      File.write!(test_module_path, """
      defmodule FileWatcherTestModule do
        def test_function(x), do: x + 1
      end
      """)

      # Compile the module
      [{module, _}] = Code.compile_file(test_module_path)

      # Give the background task time to complete
      Process.sleep(100)

      # Verify module and function were created
      assert module_record = Modules.get(FileWatcherTestModule)
      assert module_record.id == "Elixir.FileWatcherTestModule"
      assert function = Functions.get_by_mfa({FileWatcherTestModule, :test_function, 1})
      assert function.name == "test_function"

      # Delete the source file
      File.rm!(test_module_path)

      # Give file watcher time to detect deletion and process
      Process.sleep(500)

      # Verify module was removed
      refute Modules.get(FileWatcherTestModule)

      # Verify function was removed
      refute Functions.get_by_mfa({FileWatcherTestModule, :test_function, 1})

      # Clean up
      cleanup_module(module)
      File.rm_rf!(test_dir)
    end
  end
end
