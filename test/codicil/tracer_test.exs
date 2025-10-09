defmodule Codicil.TracerTest do
  use ExUnit.Case, async: true

  alias Codicil.Tracer
  alias Codicil.Function
  alias Codicil.Db.Repo

  setup do
    # Start a sandbox transaction for isolated testing
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "trace/2" do
    test "handles :on_module event with simple add_one function" do
      # Compile a module with a single function
      [{module, _}] = Code.compile_string("""
      defmodule AddOneModule do
        def add_one(x), do: x + 1
      end
      """)

      # Give the background task time to complete
      Process.sleep(100)

      # Should create a Function database entry
      assert function = Function.get_by_mfa({AddOneModule, :add_one, 1})
      assert function.name == "add_one"
      assert function.module == "Elixir.AddOneModule"
      assert function.arity == 1
      assert function.path =~ "nofile"
      assert is_integer(function.start_line)
      assert is_integer(function.end_line)

      # Clean up
      :code.purge(module)
      :code.delete(module)
    end
  end
end
