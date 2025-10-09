defmodule Codicil.FileTest do
  use ExUnit.Case, async: true

  alias Codicil.File
  alias Codicil.Db.Repo

  setup do
    # Start a sandbox transaction for isolated testing
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create/1" do
    test "creates a file with valid attributes" do
      attrs = %{
        path: "/lib/my_module.ex",
        checksum: "abc123"
      }

      assert {:ok, file} = File.create(attrs)
      assert is_integer(file.id)
      assert file.path == "/lib/my_module.ex"
      assert file.checksum == "abc123"
      assert %DateTime{} = file.parsed
    end

    test "returns error with invalid attributes" do
      attrs = %{path: nil}

      assert {:error, changeset} = File.create(attrs)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end
  end

  describe "get/1" do
    test "retrieves a file by id" do
      {:ok, created} = File.create(%{
        path: "/test/file.ex",
        checksum: "test123"
      })

      file = File.get(created.id)
      assert file.id == created.id
      assert file.path == "/test/file.ex"
      assert file.checksum == "test123"
    end

    test "returns nil when file not found" do
      assert File.get(999_999) == nil
    end
  end

  describe "update/2" do
    test "updates file attributes" do
      {:ok, file} = File.create(%{
        path: "/original.ex",
        checksum: "old"
      })

      assert {:ok, updated} = File.update(file, %{checksum: "new"})
      assert updated.id == file.id
      assert updated.checksum == "new"
    end
  end

  describe "delete/1" do
    test "deletes a file" do
      {:ok, file} = File.create(%{
        path: "/delete.ex",
        checksum: "delete123"
      })

      assert {:ok, deleted} = File.delete(file)
      assert deleted.id == file.id
      assert File.get(file.id) == nil
    end
  end
end
