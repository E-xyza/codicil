defmodule Codicil.FunctionsTest do
  use ExUnit.Case, async: false

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
      {:ok, created} =
        Functions.create(%{
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
      {:ok, function} =
        Functions.create(%{
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
      {:ok, function} =
        Functions.create(%{
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
      {:ok, _module} =
        Modules.create(%{
          id: MyModule,
          path: "/lib/my_module.ex",
          checksum: "abc123"
        })

      # Create a function belonging to that module
      {:ok, function} =
        Functions.create(%{
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
      {:ok, module} =
        Modules.create(%{
          id: TestModule,
          path: "/lib/test.ex",
          checksum: "xyz"
        })

      # Create a function
      {:ok, function} =
        Functions.create(%{
          name: :test_func,
          module: TestModule,
          arity: 0,
          exported: true,
          path: "/lib/test.ex",
          line: 5,
          checksum: "abc"
        })

      # Query function and join with module_info
      result =
        from(f in Codicil.Db.Function,
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

    test "handles mutually recursive function calls" do
      # Setup: Create module and two functions that call each other
      {:ok, _mod} = Modules.create(%{id: MyModule, path: "/lib/my_module.ex", checksum: "abc"})

      {:ok, even?} =
        Functions.create(%{
          name: :is_even,
          module: MyModule,
          arity: 1,
          exported: true,
          path: "/lib/my_module.ex",
          line: 10,
          checksum: "even123"
        })

      {:ok, odd?} =
        Functions.create(%{
          name: :is_odd,
          module: MyModule,
          arity: 1,
          exported: true,
          path: "/lib/my_module.ex",
          line: 20,
          checksum: "odd456"
        })

      # Create mutual call relationships (even? calls odd?, odd? calls even?)
      assert :ok = Functions.add_call(even?, odd?)
      assert :ok = Functions.add_call(odd?, even?)

      # Verify even? calls odd?
      even_calls = Functions.list_calls(even?)
      assert length(even_calls) == 1
      assert hd(even_calls).id == odd?.id

      # Verify odd? calls even?
      odd_calls = Functions.list_calls(odd?)
      assert length(odd_calls) == 1
      assert hd(odd_calls).id == even?.id

      # Verify reverse relationships work
      even_called_by = Functions.list_called_by(even?)
      assert length(even_called_by) == 1
      assert hd(even_called_by).id == odd?.id

      odd_called_by = Functions.list_called_by(odd?)
      assert length(odd_called_by) == 1
      assert hd(odd_called_by).id == even?.id
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

  describe "upsert/1" do
    test "creates a new function when it doesn't exist" do
      attrs = %{
        name: :my_function,
        module: MyModule,
        arity: 2,
        exported: true,
        path: "/lib/my_module.ex",
        line: 10,
        checksum: "abc123"
      }

      assert {:ok, function} = Functions.upsert(attrs)
      assert is_integer(function.id)
      assert function.name == "my_function"
      assert function.module == "Elixir.MyModule"
      assert function.arity == 2
      assert function.checksum == "abc123"
    end

    test "updates existing function when it already exists" do
      # Create initial function
      initial_attrs = %{
        name: :my_function,
        module: MyModule,
        arity: 1,
        exported: false,
        path: "/lib/old_path.ex",
        line: 5,
        checksum: "old_checksum"
      }

      {:ok, initial} = Functions.create(initial_attrs)
      initial_id = initial.id

      # Upsert with new data
      updated_attrs = %{
        name: :my_function,
        module: MyModule,
        arity: 1,
        exported: true,
        path: "/lib/new_path.ex",
        line: 10,
        checksum: "new_checksum"
      }

      assert {:ok, updated} = Functions.upsert(updated_attrs)
      assert updated.id == initial_id
      assert updated.exported == true
      assert updated.path == "/lib/new_path.ex"
      assert updated.line == 10
      assert updated.checksum == "new_checksum"
    end

    test "preserves id when upserting" do
      # Create initial function
      {:ok, initial} =
        Functions.create(%{
          name: :test,
          module: TestModule,
          arity: 0,
          exported: true,
          path: "/test.ex",
          line: 1,
          checksum: "v1"
        })

      # Upsert multiple times
      {:ok, upsert1} =
        Functions.upsert(%{
          name: :test,
          module: TestModule,
          arity: 0,
          exported: true,
          path: "/test.ex",
          line: 2,
          checksum: "v2"
        })

      {:ok, upsert2} =
        Functions.upsert(%{
          name: :test,
          module: TestModule,
          arity: 0,
          exported: true,
          path: "/test.ex",
          line: 3,
          checksum: "v3"
        })

      # All should have the same ID
      assert initial.id == upsert1.id
      assert initial.id == upsert2.id
      assert upsert2.checksum == "v3"
    end

    test "returns {:ok, function} when upserting with new checksum" do
      # Create initial function
      {:ok, initial} =
        Functions.create(%{
          name: :test,
          module: TestModule,
          arity: 0,
          exported: true,
          path: "/test.ex",
          line: 1,
          checksum: "checksum_v1"
        })

      initial_parsed = initial.parsed

      # Upsert with different checksum - should return {:ok, _}
      assert {:ok, updated} =
               Functions.upsert(%{
                 name: :test,
                 module: TestModule,
                 arity: 0,
                 exported: true,
                 path: "/test.ex",
                 line: 2,
                 checksum: "checksum_v2"
               })

      # Should have same ID but updated fields
      assert updated.id == initial.id
      assert updated.checksum == "checksum_v2"
      assert updated.line == 2
      # parsed should NOT be updated (it's in replace_all_except)
      assert updated.parsed == initial_parsed
    end

    test "returns {:same, function} when upserting with matching checksum" do
      # Create initial function
      {:ok, initial} =
        Functions.create(%{
          name: :test,
          module: TestModule,
          arity: 0,
          exported: true,
          path: "/test.ex",
          line: 1,
          checksum: "checksum_v1"
        })

      # Upsert with same checksum but different other fields
      # Should return {:same, _} because checksum matches
      assert {:same, unchanged} =
               Functions.upsert(%{
                 name: :test,
                 module: TestModule,
                 arity: 0,
                 # Different field
                 exported: false,
                 # Different field
                 path: "/different.ex",
                 # Different field
                 line: 999,
                 # SAME checksum
                 checksum: "checksum_v1"
               })

      # Should have same ID and checksum
      assert unchanged.id == initial.id
      assert unchanged.checksum == "checksum_v1"
      # Other fields should NOT be updated (conflict_where prevented update)
      assert unchanged.line == 1
      assert unchanged.path == "/test.ex"
      assert unchanged.exported == true
    end

    test "returns {:ok, function} for brand new function (no conflict)" do
      # Upsert a function that doesn't exist yet
      assert {:ok, new_function} =
               Functions.upsert(%{
                 name: :brand_new,
                 module: BrandNewModule,
                 arity: 3,
                 exported: true,
                 path: "/new.ex",
                 line: 5,
                 checksum: "new_checksum"
               })

      # Should have an ID and parsed timestamp
      assert is_integer(new_function.id)
      assert %DateTime{} = new_function.parsed
      assert new_function.checksum == "new_checksum"
    end

    test "placeholder functions have nil parsed field" do
      # Create a placeholder (no parsed field provided)
      {:ok, placeholder} =
        Functions.upsert(%{
          name: :placeholder_func,
          module: PlaceholderModule,
          arity: 1,
          checksum: "TODO"
        })

      # Verify parsed is set (upsert adds it via Map.put_new)
      assert %DateTime{} = placeholder.parsed

      # Now upsert the same placeholder again with same checksum
      assert {:same, unchanged} =
               Functions.upsert(%{
                 name: :placeholder_func,
                 module: PlaceholderModule,
                 arity: 1,
                 checksum: "TODO"
               })

      # The returned function should have the original parsed timestamp
      assert unchanged.parsed == placeholder.parsed
    end
  end
end
