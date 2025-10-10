defmodule Codicil.FunctionsTest do
  use ExUnit.Case, async: true

  alias Codicil.Functions
  alias Codicil.Modules
  alias Codicil.Db.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "add_call/2" do
    test "creates a function call relationship" do
      # Setup: Create module and functions
      {:ok, _mod} = Modules.create(%{id: MyModule, path: "/lib/my_module.ex", checksum: "abc"})

      {:ok, caller} =
        Functions.create(%{
          name: :foo,
          module: MyModule,
          arity: 0,
          exported: true,
          path: "/lib/my_module.ex",
          line: 10,
          checksum: "caller123"
        })

      {:ok, callee} =
        Functions.create(%{
          name: :bar,
          module: MyModule,
          arity: 1,
          exported: false,
          path: "/lib/my_module.ex",
          line: 20,
          checksum: "callee456"
        })

      # Create call relationship
      assert :ok = Functions.add_call(caller, callee)

      # Verify relationship exists by listing calls
      calls = Functions.list_calls(caller)
      assert length(calls) == 1
      assert hd(calls).id == callee.id
    end

    test "prevents duplicate call relationships" do
      # Setup: Create module and functions
      {:ok, _mod} = Modules.create(%{id: MyModule, path: "/lib/my_module.ex", checksum: "abc"})

      {:ok, caller} =
        Functions.create(%{
          name: :foo,
          module: MyModule,
          arity: 0,
          exported: true,
          path: "/lib/my_module.ex",
          line: 10,
          checksum: "caller123"
        })

      {:ok, callee} =
        Functions.create(%{
          name: :bar,
          module: MyModule,
          arity: 1,
          exported: false,
          path: "/lib/my_module.ex",
          line: 20,
          checksum: "callee456"
        })

      # Create call relationship twice
      assert :ok = Functions.add_call(caller, callee)
      assert :ok = Functions.add_call(caller, callee)

      # Verify only one relationship exists
      calls = Functions.list_calls(caller)
      assert length(calls) == 1
    end
  end

  describe "list_calls/1" do
    test "returns all functions called by a function" do
      # Setup: Create module and functions
      {:ok, _mod} = Modules.create(%{id: MyModule, path: "/lib/my_module.ex", checksum: "abc"})

      {:ok, caller} =
        Functions.create(%{
          name: :foo,
          module: MyModule,
          arity: 0,
          exported: true,
          path: "/lib/my_module.ex",
          line: 10,
          checksum: "caller123"
        })

      {:ok, callee1} =
        Functions.create(%{
          name: :bar,
          module: MyModule,
          arity: 1,
          exported: false,
          path: "/lib/my_module.ex",
          line: 20,
          checksum: "callee1"
        })

      {:ok, callee2} =
        Functions.create(%{
          name: :baz,
          module: MyModule,
          arity: 2,
          exported: false,
          path: "/lib/my_module.ex",
          line: 30,
          checksum: "callee2"
        })

      # Create call relationships
      Functions.add_call(caller, callee1)
      Functions.add_call(caller, callee2)

      # List all calls
      calls = Functions.list_calls(caller)
      assert length(calls) == 2
      call_ids = Enum.map(calls, & &1.id) |> Enum.sort()
      assert call_ids == [callee1.id, callee2.id] |> Enum.sort()
    end

    test "returns empty list when function makes no calls" do
      # Setup: Create module and function
      {:ok, _mod} = Modules.create(%{id: MyModule, path: "/lib/my_module.ex", checksum: "abc"})

      {:ok, function} =
        Functions.create(%{
          name: :foo,
          module: MyModule,
          arity: 0,
          exported: true,
          path: "/lib/my_module.ex",
          line: 10,
          checksum: "func123"
        })

      # List calls from function with no calls
      calls = Functions.list_calls(function)
      assert calls == []
    end
  end
end
