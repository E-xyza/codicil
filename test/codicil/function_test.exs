defmodule Codicil.FunctionsTest do
  use ExUnit.Case, async: true

  alias Codicil.Functions
  alias Codicil.Modules
  alias Codicil.Db.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create/1" do
    test "creates a function with valid attributes" do
      attrs = %{
        name: :my_function,
        module: MyModule,
        arity: 2,
        exported: true,
        path: "/lib/my_module.ex",
        line: 10,
        checksum: "abc123def456"
      }

      assert {:ok, function} = Functions.create(attrs)
      assert is_integer(function.id)
      assert function.name == "my_function"
      assert function.module == "Elixir.MyModule"
      assert function.arity == 2
      assert function.exported
      assert function.path == "/lib/my_module.ex"
      assert function.line == 10
      assert function.checksum == "abc123def456"
      assert %DateTime{} = function.parsed
    end

    test "returns error with invalid attributes" do
      attrs = %{name: nil}

      assert {:error, changeset} = Functions.create(attrs)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end
  end

  describe "get/1" do
    test "retrieves a function by id" do
      {:ok, created} = Functions.create(%{
        name: :test_func,
        module: TestModule,
        arity: 1,
        exported: true,
        path: "/test.ex",
        line: 1,
        checksum: "test123"
      })

      function = Functions.get(created.id)
      assert function.id == created.id
      assert function.name == "test_func"
      assert function.arity == 1
    end

    test "returns nil when function not found" do
      assert Functions.get(999_999) == nil
    end
  end

  describe "update/2" do
    test "updates function attributes" do
      {:ok, function} = Functions.create(%{
        name: :original,
        module: Module,
        arity: 0,
        exported: false,
        path: "/path.ex",
        line: 1,
        checksum: "check1"
      })

      assert {:ok, updated} = Functions.update(function, %{summary: "New summary"})
      assert updated.id == function.id
      assert updated.summary == "New summary"
    end
  end

  describe "delete/1" do
    test "deletes a function" do
      {:ok, function} = Functions.create(%{
        name: :to_delete,
        module: Module,
        arity: 3,
        exported: true,
        path: "/path.ex",
        line: 1,
        checksum: "check1"
      })

      assert {:ok, deleted} = Functions.delete(function)
      assert deleted.id == function.id
      assert Functions.get(function.id) == nil
    end
  end

  describe "relations" do
    test "can preload module_info from function" do
      # Create a module
      {:ok, module} = Modules.create(%{
        id: MyModule,
        path: "/lib/my_module.ex",
        checksum: "abc123"
      })

      # Create a function belonging to that module
      {:ok, function} = Functions.create(%{
        name: :my_function,
        module: MyModule,
        arity: 1,
        exported: true,
        path: "/lib/my_module.ex",
        line: 10,
        checksum: "def456"
      })

      # Preload the module_info association
      function_with_module = Repo.preload(function, :module_info)

      assert function_with_module.module_info.id == "Elixir.MyModule"
      assert function_with_module.module_info.path == "/lib/my_module.ex"
    end

    test "can query functions through module_info association" do
      import Ecto.Query

      # Create a module
      {:ok, module} = Modules.create(%{
        id: TestModule,
        path: "/lib/test.ex",
        checksum: "xyz"
      })

      # Create a function
      {:ok, function} = Functions.create(%{
        name: :test_func,
        module: TestModule,
        arity: 0,
        exported: true,
        path: "/lib/test.ex",
        line: 5,
        checksum: "abc"
      })

      # Query function and join with module_info
      result = from(f in Codicil.Db.Function,
        join: m in assoc(f, :module_info),
        where: m.id == ^module.id,
        select: f
      )
      |> Repo.one()

      assert result.name == "test_func"
      assert result.id == function.id
    end
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

  describe "list_called_by/1" do
    test "returns all functions that call a function" do
      # Setup: Create module and functions
      {:ok, _mod} = Modules.create(%{id: MyModule, path: "/lib/my_module.ex", checksum: "abc"})

      {:ok, callee} =
        Functions.create(%{
          name: :bar,
          module: MyModule,
          arity: 1,
          exported: false,
          path: "/lib/my_module.ex",
          line: 20,
          checksum: "callee123"
        })

      {:ok, caller1} =
        Functions.create(%{
          name: :foo,
          module: MyModule,
          arity: 0,
          exported: true,
          path: "/lib/my_module.ex",
          line: 10,
          checksum: "caller1"
        })

      {:ok, caller2} =
        Functions.create(%{
          name: :baz,
          module: MyModule,
          arity: 2,
          exported: false,
          path: "/lib/my_module.ex",
          line: 30,
          checksum: "caller2"
        })

      # Create call relationships
      Functions.add_call(caller1, callee)
      Functions.add_call(caller2, callee)

      # List all callers
      callers = Functions.list_called_by(callee)
      assert length(callers) == 2
      caller_ids = Enum.map(callers, & &1.id) |> Enum.sort()
      assert caller_ids == [caller1.id, caller2.id] |> Enum.sort()
    end

    test "returns empty list when function is not called by anyone" do
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

      # List callers of function that's not called
      callers = Functions.list_called_by(function)
      assert callers == []
    end
  end
end
