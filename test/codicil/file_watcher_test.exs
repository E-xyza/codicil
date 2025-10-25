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

    # Enable tracer for recompilation tests
    Code.put_compiler_option(:tracers, [Codicil.Tracer])

    on_exit(fn ->
      Code.put_compiler_option(:tracers, [])
    end)

    :ok
  end

  describe "module retirement on file deletion" do
    test "marks module and its functions for deletion when file deleted event received" do
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

      # Verify module and function exist and are not marked
      module = Modules.get(TestModule)
      assert module
      refute module.marked_for_deletion

      function = Functions.get_by_mfa({TestModule, :test_function, 1})
      assert function
      refute function.marked_for_deletion

      # Send file deletion event to FileWatcher
      send(Codicil.FileWatcher, {:file_event, self(), {test_path, [:deleted]}})

      # Give FileWatcher time to process
      Process.sleep(100)

      # Verify module is marked for deletion (not deleted)
      module = Modules.get(TestModule)
      assert module
      assert module.marked_for_deletion

      # Verify function is marked for deletion (not deleted)
      function = Functions.get_by_mfa({TestModule, :test_function, 1})
      assert function
      assert function.marked_for_deletion
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

    test "recompiles file when modified event received" do
      # Create a real test file in tmp directory
      tmp_dir = System.tmp_dir!()
      test_path = Path.join(tmp_dir, "file_watcher_recompile_test.ex")

      # Clean up any existing module first
      :code.purge(FileWatcherRecompileTest)
      :code.delete(FileWatcherRecompileTest)

      # Clean up on exit
      on_exit(fn ->
        :code.purge(FileWatcherRecompileTest)
        :code.delete(FileWatcherRecompileTest)
        File.rm(test_path)
      end)

      File.write!(test_path, """
      defmodule FileWatcherRecompileTest do
        def version, do: 1
      end
      """)

      # Compile it initially
      Code.compile_file(test_path)
      Process.sleep(100)

      # Verify initial function exists
      assert Functions.get_by_mfa({FileWatcherRecompileTest, :version, 0})

      # Modify the file (add a new function)
      File.write!(test_path, """
      defmodule FileWatcherRecompileTest do
        def version, do: 2
        def new_function, do: :ok
      end
      """)

      # Send modified event
      send(Codicil.FileWatcher, {:file_event, self(), {test_path, [:modified]}})

      # Give FileWatcher time to recompile
      Process.sleep(100)

      # Verify new function was added
      assert Functions.get_by_mfa({FileWatcherRecompileTest, :new_function, 0})

      # Verify original function still exists (may have been updated)
      assert Functions.get_by_mfa({FileWatcherRecompileTest, :version, 0})
    end

    test "file rename reuses existing data and avoids LLM calls" do
      # Create a real test file at old path in tmp directory
      tmp_dir = System.tmp_dir!()
      old_path = Path.join(tmp_dir, "rename_test_old.ex")
      new_path = Path.join(tmp_dir, "rename_test_new.ex")

      # Clean up on exit
      on_exit(fn ->
        :code.purge(RenameTestModule)
        :code.delete(RenameTestModule)
        File.rm(old_path)
        File.rm(new_path)
      end)

      File.write!(old_path, """
      defmodule RenameTestModule do
        def original_function, do: :ok
      end
      """)

      # Compile it initially
      Code.compile_file(old_path)
      Process.sleep(100)

      # Verify initial state - module and function exist at old path
      module = Modules.get(RenameTestModule)
      assert module
      assert module.path == old_path
      refute module.marked_for_deletion
      original_checksum = module.checksum
      original_summary = module.summary

      function = Functions.get_by_mfa({RenameTestModule, :original_function, 0})
      assert function
      assert function.path == old_path
      refute function.marked_for_deletion
      original_function_checksum = function.checksum

      # Simulate rename: delete old, create new
      send(Codicil.FileWatcher, {:file_event, self(), {old_path, [:deleted]}})
      Process.sleep(50)

      # Verify marked for deletion
      module = Modules.get(RenameTestModule)
      assert module.marked_for_deletion
      function = Functions.get_by_mfa({RenameTestModule, :original_function, 0})
      assert function.marked_for_deletion

      # Create file at new location (same content)
      File.write!(new_path, """
      defmodule RenameTestModule do
        def original_function, do: :ok
      end
      """)

      send(Codicil.FileWatcher, {:file_event, self(), {new_path, [:created]}})
      Process.sleep(100)

      # Verify module data was reused (unmarked, path updated, checksum preserved)
      module = Modules.get(RenameTestModule)
      assert module
      assert module.path == new_path
      refute module.marked_for_deletion
      assert module.checksum == original_checksum
      assert module.summary == original_summary

      # Verify function data was reused
      function = Functions.get_by_mfa({RenameTestModule, :original_function, 0})
      assert function
      assert function.path == new_path
      refute function.marked_for_deletion
      assert function.checksum == original_function_checksum
    end
  end
end
