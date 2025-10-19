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

    :ok
  end

  describe "module retirement on file deletion" do
    test "removes module and its functions when file deleted event received" do
      # Create a module record
      test_path = "/lib/test_module.ex"

      {:ok, _module_record} =
        Modules.upsert(%{
          id: "Elixir.TestModule",
          path: test_path,
          checksum: "abc123"
        })

      # Create a function for this module
      {:ok, _function} =
        Functions.upsert(%{
          name: :test_function,
          module: TestModule,
          arity: 1,
          exported: true,
          path: test_path,
          line: 10,
          checksum: "def456"
        })

      # Verify module and function exist
      assert Modules.get(TestModule)
      assert Functions.get_by_mfa({TestModule, :test_function, 1})

      # Send file deletion event to FileWatcher
      send(Codicil.FileWatcher, {:file_event, self(), {test_path, [:deleted]}})

      # Give FileWatcher time to process
      Process.sleep(100)

      # Verify module was removed
      refute Modules.get(TestModule)

      # Verify function was removed
      refute Functions.get_by_mfa({TestModule, :test_function, 1})
    end

    test "ignores non-elixir file deletions" do
      # Create a module record
      test_path = "/lib/test_module.ex"

      {:ok, _module_record} =
        Modules.upsert(%{
          id: "Elixir.TestModule2",
          path: test_path,
          checksum: "abc123"
        })

      # Send deletion event for a non-elixir file
      send(Codicil.FileWatcher, {:file_event, self(), {"/lib/readme.md", [:deleted]}})

      # Give FileWatcher time to process
      Process.sleep(100)

      # Verify module still exists (not deleted)
      assert Modules.get(TestModule2)
    end
  end
end
