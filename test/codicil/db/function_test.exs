defmodule Codicil.Db.FunctionTest do
  use ExUnit.Case, async: true

  alias Codicil.Function
  alias Codicil.Db.Repo

  setup do
    # Start a sandbox transaction for isolated testing
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

      assert {:ok, function} = Function.create(attrs)
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

      assert {:error, changeset} = Function.create(attrs)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end
  end

  describe "get/1" do
    test "retrieves a function by id" do
      {:ok, created} = Function.create(%{
        name: :test_func,
        module: TestModule,
        arity: 1,
        exported: true,
        path: "/test.ex",
        line: 1,
        checksum: "test123"
      })

      function = Function.get(created.id)
      assert function.id == created.id
      assert function.name == "test_func"
      assert function.arity == 1
    end

    test "returns nil when function not found" do
      assert Function.get(999_999) == nil
    end
  end

  describe "update/2" do
    test "updates function attributes" do
      {:ok, function} = Function.create(%{
        name: :original,
        module: Module,
        arity: 0,
        exported: false,
        path: "/path.ex",
        line: 1,
        checksum: "check1"
      })

      assert {:ok, updated} = Function.update(function, %{summary: "New summary"})
      assert updated.id == function.id
      assert updated.summary == "New summary"
    end
  end

  describe "delete/1" do
    test "deletes a function" do
      {:ok, function} = Function.create(%{
        name: :to_delete,
        module: Module,
        arity: 3,
        exported: true,
        path: "/path.ex",
        line: 1,
        checksum: "check1"
      })

      assert {:ok, deleted} = Function.delete(function)
      assert deleted.id == function.id
      assert Function.get(function.id) == nil
    end
  end

  describe "relations" do
    test "can preload mod from function" do
      alias Codicil.Mod

      # Create a module
      {:ok, mod} = Mod.create(%{
        id: MyModule,
        path: "/lib/my_module.ex",
        checksum: "abc123"
      })

      # Create a function belonging to that module
      {:ok, function_record} = Repo.insert(%Codicil.Db.Function{
        name: "my_function",
        module: mod.id,
        arity: 1,
        exported: true,
        path: "/lib/my_module.ex",
        line: 10,
        checksum: "def456"
      })

      # Preload the mod association
      function_with_mod = Repo.preload(function_record, :mod)

      assert function_with_mod.mod.id == "Elixir.MyModule"
      assert function_with_mod.mod.path == "/lib/my_module.ex"
    end

    test "can query functions through mod association" do
      alias Codicil.Mod
      import Ecto.Query

      # Create a module
      {:ok, mod} = Mod.create(%{
        id: TestModule,
        path: "/lib/test.ex",
        checksum: "xyz"
      })

      # Create a function
      {:ok, _function} = Repo.insert(%Codicil.Db.Function{
        name: "test_func",
        module: mod.id,
        arity: 0,
        exported: true,
        path: "/lib/test.ex",
        line: 5,
        checksum: "abc"
      })

      # Query function and join with mod
      result = from(f in Codicil.Db.Function,
        join: m in assoc(f, :mod),
        where: m.id == ^mod.id,
        select: f
      )
      |> Repo.one()

      assert result.name == "test_func"
    end
  end
end
