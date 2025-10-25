defmodule Codicil.FileWatcher do
  @moduledoc """
  Watches file system for deletions and retires modules when source files are deleted.

  Subscribes to the Codicil.FsWatcher FileSystem process that is managed by the
  supervision tree.
  """
  use GenServer

  alias Codicil.Functions
  alias Codicil.Modules

  # BOILERPLATE & INITIALIZATION

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    # Subscribe to the FileSystem process managed by the supervision tree
    FileSystem.subscribe(Codicil.FsWatcher)

    {:ok, %{}}
  end

  # ROUTER

  @impl true
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    if Path.extname(path) in [".ex", ".exs"] do
      cond do
        # File was deleted or removed - retire modules
        :deleted in events or :removed in events ->
          retire_modules_for_path(path)

        # File was created or modified - trigger recompilation
        :created in events or :modified in events ->
          recompile_file(path)

        true ->
          :ok
      end
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    {:noreply, state}
  end

  # HELPER FUNCTIONS

  defp retire_modules_for_path(path) do
    # Get all modules associated with this file path
    modules = Modules.list_by_path(path)

    for module <- modules do
      module_atom = String.to_atom(module.id)

      # If this is a .ex file, purge and delete the compiled module from BEAM
      if Path.extname(path) == ".ex" do
        :code.purge(module_atom)
        :code.delete(module_atom)
      end

      # Delete all functions for this module
      functions = Functions.list_by_module(module_atom)

      for function <- functions do
        Functions.delete(function)
      end

      # Delete the module itself
      Modules.delete(module)
    end
  end

  defp recompile_file(path) do
    # Compile the file - this will trigger the tracer which will update the database
    Code.compile_file(path)
  rescue
    # Ignore compilation errors - let the user handle them
    _ -> :ok
  end
end
