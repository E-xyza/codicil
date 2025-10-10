defmodule Codicil.Db.FunctionTest do
  use ExUnit.Case, async: true

  alias Codicil.Functions
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
      {:ok, module} = Codicil.Modules.create(%{
        id: MyModule,
        path: "/lib/my_module.ex",
        checksum: "abc123"
      })

      # Create a function belonging to that module
      {:ok, function_record} = Repo.insert(%Codicil.Db.Function{
        name: "my_function",
        module: module.id,
        arity: 1,
        exported: true,
        path: "/lib/my_module.ex",
        line: 10,
        checksum: "def456"
      })

      # Preload the module_info association
      function_with_module = Repo.preload(function_record, :module_info)

      assert function_with_module.module_info.id == "Elixir.MyModule"
      assert function_with_module.module_info.path == "/lib/my_module.ex"
    end

    test "can query functions through module_info association" do
      import Ecto.Query

      # Create a module
      {:ok, module} = Codicil.Modules.create(%{
        id: TestModule,
        path: "/lib/test.ex",
        checksum: "xyz"
      })

      # Create a function
      {:ok, _function} = Repo.insert(%Codicil.Db.Function{
        name: "test_func",
        module: module.id,
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
    end
  end
end
