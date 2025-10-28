defmodule Codicil.Startup do
  # Task that runs once on application startup.
  #
  # Performs:
  # 1. Garbage collection of marked functions and modules
  # 2. Scans for incomplete database entries and queues them for processing
  @moduledoc false

  use Task, restart: :transient

  require Logger

  alias Codicil.Functions
  alias Codicil.Modules
  alias Codicil.RateLimiter

  def start_link(_arg) do
    # Only start if RateLimiter is running (skips when clients not configured)
    if Process.whereis(RateLimiter) do
      Task.start_link(__MODULE__, :run, [])
    else
      :ignore
    end
  end

  def run do
    # Step 1: Garbage collect marked entries
    garbage_collect_marked()

    # Step 2: Scan for incomplete entries and queue for processing
    scan_incomplete_entries()

    :ok
  end

  defp garbage_collect_marked do
    {module_count, _} = Modules.garbage_collect_marked()
    {function_count, _} = Functions.garbage_collect_marked()

    if module_count > 0 or function_count > 0 do
      Logger.info(
        "Garbage collected #{module_count} modules and #{function_count} functions marked for deletion"
      )
    end
  end

  defp scan_incomplete_entries do
    Logger.info("Scanning for incomplete function entries...")

    # Find functions that need processing:
    # 1. Exported functions without summary (need summarization from code)
    # 2. Functions with docs but without summary (need summarization from docs)
    # 3. Functions with summary but without embedding (need embedding)
    incomplete_functions = Functions.list_incomplete()

    count = length(incomplete_functions)

    if count > 0 do
      Logger.info("Found #{count} incomplete function entries, queueing for processing")

      Enum.each(incomplete_functions, fn function ->
        RateLimiter.enqueue(%{
          id: function.id,
          name: function.name,
          module: function.module,
          path: function.path,
          docs: function.docs,
          code: function.code,
          exported: function.exported
        })
      end)
    else
      Logger.info("No incomplete function entries found")
    end
  end
end
