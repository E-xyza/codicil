defmodule Codicil.EdgeTest do
  use ExUnit.Case, async: true

  alias Codicil.Edge
  alias Codicil.Db.Repo

  setup do
    # Start a sandbox transaction for isolated testing
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create/1" do
    test "creates an edge with valid attributes" do
      attrs = %{
        from_id: 1,
        to_id: 2,
        type: :calls
      }

      assert {:ok, edge} = Edge.create(attrs)
      assert is_integer(edge.id)
      assert edge.from_id == 1
      assert edge.to_id == 2
      assert edge.type == :calls
    end

    test "returns error with invalid attributes" do
      attrs = %{from_id: nil}

      assert {:error, changeset} = Edge.create(attrs)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end
  end

  describe "get/1" do
    test "retrieves an edge by id" do
      {:ok, created} = Edge.create(%{
        from_id: 10,
        to_id: 20,
        type: :imports_from
      })

      edge = Edge.get(created.id)
      assert edge.id == created.id
      assert edge.from_id == 10
      assert edge.to_id == 20
      assert edge.type == :imports_from
    end

    test "returns nil when edge not found" do
      assert Edge.get(999_999) == nil
    end
  end

  describe "delete/1" do
    test "deletes an edge" do
      {:ok, edge} = Edge.create(%{
        from_id: 5,
        to_id: 6,
        type: :calls
      })

      assert {:ok, deleted} = Edge.delete(edge)
      assert deleted.id == edge.id
      assert Edge.get(edge.id) == nil
    end
  end
end
