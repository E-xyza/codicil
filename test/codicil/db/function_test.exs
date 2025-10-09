defmodule Codicil.FunctionTest do
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
        name: "my_function",
        module: "Elixir.MyModule",
        arity: 2,
        exported: true,
        path: "/lib/my_module.ex",
        start_line: 10,
        end_line: 25,
        checksum: "abc123def456"
      }

      assert {:ok, function} = Function.create(attrs)
      assert is_integer(function.id)
      assert function.name == "my_function"
      assert function.module == "Elixir.MyModule"
      assert function.arity == 2
      assert function.exported
      assert function.path == "/lib/my_module.ex"
      assert function.start_line == 10
      assert function.end_line == 25
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
        name: "test_func",
        module: "TestModule",
        arity: 1,
        exported: true,
        path: "/test.ex",
        start_line: 1,
        end_line: 5,
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
        name: "original",
        module: "Module",
        arity: 0,
        exported: false,
        path: "/path.ex",
        start_line: 1,
        end_line: 2,
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
        name: "to_delete",
        module: "Module",
        arity: 3,
        exported: true,
        path: "/path.ex",
        start_line: 1,
        end_line: 2,
        checksum: "check1"
      })

      assert {:ok, deleted} = Function.delete(function)
      assert deleted.id == function.id
      assert Function.get(function.id) == nil
    end
  end
end
