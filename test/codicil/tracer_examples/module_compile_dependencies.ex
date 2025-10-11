defmodule ModuleCompileDependencies do
  # Import provides compile-time dependency
  import String, only: [upcase: 1]

  # Require for macros (compile-time dependency)
  require Logger

  # Use creates compile-time dependency (runs macro at compile time)
  use GenServer

  def test_import do
    upcase("hello")
  end

  def test_require do
    Logger.info("test")
  end
end
