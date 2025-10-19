defmodule Codicil.ModuleDependencyTest do
  use ExUnit.Case, async: false

  alias Codicil.Modules
  alias Codicil.Db.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create_dependency/1" do
    test "creates a compiler dependency between two modules" do
      # Setup: Create two modules first
      {:ok, mod_a} = Modules.create(%{id: ModA, path: "/lib/mod_a.ex", checksum: "aaa"})
      {:ok, mod_b} = Modules.create(%{id: ModB, path: "/lib/mod_b.ex", checksum: "bbb"})

      attrs = %{
        dependent_id: mod_a.id,
        dependency_id: mod_b.id,
        type: :compiler
      }

      assert {:ok, dependency} = Modules.create_dependency(attrs)
      assert dependency.dependent_id == "Elixir.ModA"
      assert dependency.dependency_id == "Elixir.ModB"
      assert dependency.type == :compiler
    end

    test "returns error with invalid attributes" do
      attrs = %{
        dependent_id: NonExistentModule,
        dependency_id: AnotherFakeModule,
        type: :invalid_type
      }

      assert {:error, changeset} = Modules.create_dependency(attrs)
      refute changeset.valid?
    end
  end

  describe "relations" do
    test "can preload dependent and dependency modules" do
      import Ecto.Query

      # Create two modules
      {:ok, mod_a} = Modules.create(%{id: ModA, path: "/lib/mod_a.ex", checksum: "aaa"})
      {:ok, mod_b} = Modules.create(%{id: ModB, path: "/lib/mod_b.ex", checksum: "bbb"})

      # Create a dependency: ModA depends on ModB
      {:ok, dep} =
        Repo.insert(%Codicil.Db.ModuleDependency{
          dependent_id: mod_a.id,
          dependency_id: mod_b.id,
          type: :compiler
        })

      # Preload both associations
      dep_with_mods = Repo.preload(dep, [:dependent, :dependency])

      assert dep_with_mods.dependent.id == "Elixir.ModA"
      assert dep_with_mods.dependency.id == "Elixir.ModB"
      assert dep_with_mods.type == :compiler
    end

    test "can query dependencies through associations" do
      import Ecto.Query

      # Create modules
      {:ok, mod_x} = Modules.create(%{id: ModX, path: "/lib/mod_x.ex", checksum: "xxx"})
      {:ok, mod_y} = Modules.create(%{id: ModY, path: "/lib/mod_y.ex", checksum: "yyy"})

      # Create runtime dependency
      {:ok, _dep} =
        Repo.insert(%Codicil.Db.ModuleDependency{
          dependent_id: mod_x.id,
          dependency_id: mod_y.id,
          type: :runtime
        })

      # Query to find what ModX depends on
      dependencies =
        from(md in Codicil.Db.ModuleDependency,
          join: dep in assoc(md, :dependency),
          where: md.dependent_id == ^mod_x.id,
          select: dep
        )
        |> Repo.all()

      assert length(dependencies) == 1
      assert hd(dependencies).id == "Elixir.ModY"
    end

    test "can query what modules depend on a given module" do
      import Ecto.Query

      # Create modules
      {:ok, lib_mod} = Modules.create(%{id: LibModule, path: "/lib/lib.ex", checksum: "lib"})
      {:ok, app1} = Modules.create(%{id: App1, path: "/lib/app1.ex", checksum: "app1"})
      {:ok, app2} = Modules.create(%{id: App2, path: "/lib/app2.ex", checksum: "app2"})

      # Both apps depend on lib
      {:ok, _d1} =
        Repo.insert(%Codicil.Db.ModuleDependency{
          dependent_id: app1.id,
          dependency_id: lib_mod.id,
          type: :compiler
        })

      {:ok, _d2} =
        Repo.insert(%Codicil.Db.ModuleDependency{
          dependent_id: app2.id,
          dependency_id: lib_mod.id,
          type: :compiler
        })

      # Query to find what depends on LibModule
      dependents =
        from(md in Codicil.Db.ModuleDependency,
          join: dep in assoc(md, :dependent),
          where: md.dependency_id == ^lib_mod.id,
          select: dep
        )
        |> Repo.all()
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert dependents == ["Elixir.App1", "Elixir.App2"]
    end
  end
end
