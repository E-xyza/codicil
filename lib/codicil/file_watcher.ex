defmodule Codicil.FileWatcher do
  @moduledoc """
  Watches file system for deletions and retires modules when source files are deleted.

  TODO: Handle conflict when another subsystem (e.g. Phoenix) uses FileSystem.
  Currently assumes exclusive use of FileSystem. In production, this may need
  to coordinate with other watchers or use a shared watcher infrastructure.
  """
  use GenServer

  alias Codicil.Functions
  alias Codicil.Modules

  # BOILERPLATE & INITIALIZATION

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Get the directories to watch from options or use current directory
    dirs = Keyword.get(opts, :dirs, [File.cwd!()])

    # Start FileSystem watcher
    {:ok, watcher_pid} = FileSystem.start_link(dirs: dirs)
    FileSystem.subscribe(watcher_pid)

    {:ok, %{watcher_pid: watcher_pid, dirs: dirs}}
  end

  # ROUTER

  @impl true
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    # Check if file was deleted or removed
    if :deleted in events or :removed in events do
      # Retire modules associated with this path
      if Path.extname(path) in [".ex", ".exs"] do
        retire_modules_for_path(path)
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
end
