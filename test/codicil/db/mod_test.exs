defmodule Codicil.ModTest do
  use ExUnit.Case, async: true

  alias Codicil.Mod
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

      assert {:ok, mod} = Mod.create(attrs)
      assert is_binary(mod.id)
      assert mod.id == "Elixir.MyApp.MyModule"
      assert mod.path == "/lib/my_module.ex"
      assert mod.checksum == "abc123"
      assert %DateTime{} = mod.parsed
    end

    test "returns error with invalid attributes" do
      attrs = %{path: nil}

      assert {:error, changeset} = Mod.create(attrs)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end
  end

  describe "get/1" do
    test "retrieves a module by id" do
      {:ok, created} = Mod.create(%{
        id: Test.Module,
        path: "/test/file.ex",
        checksum: "test123"
      })

      mod = Mod.get(Test.Module)
      assert mod.id == created.id
      assert mod.path == "/test/file.ex"
      assert mod.checksum == "test123"
    end

    test "returns nil when module not found" do
      assert Mod.get(NonExistent.Module) == nil
    end
  end

  describe "update/2" do
    test "updates module attributes" do
      {:ok, mod} = Mod.create(%{
        id: Update.Test,
        path: "/original.ex",
        checksum: "old"
      })

      assert {:ok, updated} = Mod.update(mod, %{checksum: "new"})
      assert updated.id == mod.id
      assert updated.checksum == "new"
    end
  end

  describe "delete/1" do
    test "deletes a module" do
      {:ok, mod} = Mod.create(%{
        id: Delete.Test,
        path: "/delete.ex",
        checksum: "delete123"
      })

      assert {:ok, deleted} = Mod.delete(mod)
      assert deleted.id == mod.id
      assert Mod.get(Delete.Test) == nil
    end
  end
end
