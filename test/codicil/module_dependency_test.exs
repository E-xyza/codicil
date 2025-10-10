defmodule Codicil.ModuleDependencyTest do
  use ExUnit.Case, async: true

  alias Codicil.ModuleDependency
  alias Codicil.Mod
  alias Codicil.Db.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create/1" do
    test "creates a compiler dependency between two modules" do
      # Setup: Create two modules first
      {:ok, mod_a} = Mod.create(%{id: ModA, path: "/lib/mod_a.ex", checksum: "aaa"})
      {:ok, mod_b} = Mod.create(%{id: ModB, path: "/lib/mod_b.ex", checksum: "bbb"})

      attrs = %{
        dependent_id: mod_a.id,
        dependency_id: mod_b.id,
        type: :compiler
      }

      assert {:ok, dependency} = ModuleDependency.create(attrs)
      assert dependency.dependent_id == "Elixir.ModA"
      assert dependency.dependency_id == "Elixir.ModB"
      assert dependency.type == :compiler
    end

    test "returns error with invalid attributes" do
      attrs = %{dependent_id: nil}

      assert {:error, changeset} = ModuleDependency.create(attrs)
      refute changeset.valid?
    end
  end
end
