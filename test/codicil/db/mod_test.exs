defmodule Codicil.Db.ModuleTest do
  use ExUnit.Case, async: true

  alias Codicil.Modules
  alias Codicil.Db.Repo

  setup do
    # Start a sandbox transaction for isolated testing
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create/1" do
    test "creates a module with valid attributes" do
      attrs = %{
        id: MyApp.MyModule,
        path: "/lib/my_module.ex",
        checksum: "abc123"
      }

      assert {:ok, module} = Modules.create(attrs)
      assert is_binary(module.id)
      assert module.id == "Elixir.MyApp.MyModule"
      assert module.path == "/lib/my_module.ex"
      assert module.checksum == "abc123"
      assert %DateTime{} = module.parsed
    end

    test "returns error with invalid attributes" do
      attrs = %{path: nil}

      assert {:error, changeset} = Modules.create(attrs)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end
  end

  describe "get/1" do
    test "retrieves a module by id" do
      {:ok, created} = Modules.create(%{
        id: Test.Module,
        path: "/test/file.ex",
        checksum: "test123"
      })

      module = Modules.get(Test.Module)
      assert module.id == created.id
      assert module.path == "/test/file.ex"
      assert module.checksum == "test123"
    end

    test "returns nil when module not found" do
      assert Modules.get(NonExistent.Module) == nil
    end
  end

  describe "update/2" do
    test "updates module attributes" do
      {:ok, module} = Modules.create(%{
        id: Update.Test,
        path: "/original.ex",
        checksum: "old"
      })

      assert {:ok, updated} = Modules.update(module, %{checksum: "new"})
      assert updated.id == module.id
      assert updated.checksum == "new"
    end
  end

  describe "delete/1" do
    test "deletes a module" do
      {:ok, module} = Modules.create(%{
        id: Delete.Test,
        path: "/delete.ex",
        checksum: "delete123"
      })

      assert {:ok, deleted} = Modules.delete(module)
      assert deleted.id == module.id
      assert Modules.get(Delete.Test) == nil
    end
  end

  describe "relations" do
    test "can preload functions from module" do
      # Create a module
      {:ok, module_record} = Repo.insert(%Codicil.Db.Module{
        id: "Elixir.MultiFunc",
        path: "/lib/multi.ex",
        checksum: "multi123"
      })

      # Create multiple functions
      {:ok, _f1} = Repo.insert(%Codicil.Db.Function{
        name: "func_one",
        module: module_record.id,
        arity: 0,
        exported: true,
        path: "/lib/multi.ex",
        line: 10,
        checksum: "f1"
      })

      {:ok, _f2} = Repo.insert(%Codicil.Db.Function{
        name: "func_two",
        module: module_record.id,
        arity: 1,
        exported: false,
        path: "/lib/multi.ex",
        line: 20,
        checksum: "f2"
      })

      # Preload functions association
      module_with_functions = Repo.preload(module_record, :functions)

      assert length(module_with_functions.functions) == 2
      function_names = Enum.map(module_with_functions.functions, & &1.name) |> Enum.sort()
      assert function_names == ["func_one", "func_two"]
    end

    test "functions are empty when module has no functions" do
      # Create a module with no functions
      {:ok, module_record} = Repo.insert(%Codicil.Db.Module{
        id: "Elixir.Empty",
        path: "/lib/empty.ex",
        checksum: "empty"
      })

      module_with_functions = Repo.preload(module_record, :functions)

      assert module_with_functions.functions == []
    end
  end
end
