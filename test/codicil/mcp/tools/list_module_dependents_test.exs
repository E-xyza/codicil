defmodule Codicil.MCP.Tools.ListModuleDependentsTest do
  use ExUnit.Case, async: false

  alias Codicil.Db.Repo
  alias Codicil.Modules

  setup do
    # Sandbox for test isolation
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Create target module (the one others depend ON)
    {:ok, target} =
      Modules.upsert(%{
        id: "Elixir.MyApp.SharedModule",
        path: "/lib/my_app/shared_module.ex",
        checksum: "abc123"
      })

    # Create dependent modules (the ones that depend on target)
    {:ok, dependent1} =
      Modules.upsert(%{
        id: "Elixir.MyApp.Consumer",
        path: "/lib/my_app/consumer.ex",
        checksum: "def456"
      })

    {:ok, dependent2} =
      Modules.upsert(%{
        id: "Elixir.MyApp.AnotherConsumer",
        path: "/lib/my_app/another_consumer.ex",
        checksum: "ghi789"
      })

    # Create compile-time dependency (dependent1 imports/requires target)
    Modules.create_dependency(%{
      dependent_id: dependent1.id,
      dependency_id: target.id,
      type: :compiler
    })

    # Create runtime dependency (dependent2 calls functions in target)
    Modules.create_dependency(%{
      dependent_id: dependent2.id,
      dependency_id: target.id,
      type: :runtime
    })

    %{target: target, dependent1: dependent1, dependent2: dependent2}
  end

  test "returns all dependents for a module", %{target: _target} do
    args = %{
      "moduleName" => "Elixir.MyApp.SharedModule"
    }

    assert {:ok, result} = Codicil.MCP.Tools.ListModuleDependents.call(args)
    assert result =~ "MyApp.Consumer"
    assert result =~ "MyApp.AnotherConsumer"
    assert result =~ "compile-time"
    assert result =~ "runtime"
  end

  test "filters by compile-time dependents only" do
    args = %{
      "moduleName" => "Elixir.MyApp.SharedModule",
      "type" => "compiler"
    }

    assert {:ok, result} = Codicil.MCP.Tools.ListModuleDependents.call(args)
    assert result =~ "MyApp.Consumer"
    assert result =~ "compile-time"
    refute result =~ "MyApp.AnotherConsumer"
    refute result =~ "runtime"
  end

  test "filters by runtime dependents only" do
    args = %{
      "moduleName" => "Elixir.MyApp.SharedModule",
      "type" => "runtime"
    }

    assert {:ok, result} = Codicil.MCP.Tools.ListModuleDependents.call(args)
    assert result =~ "MyApp.AnotherConsumer"
    assert result =~ "runtime"
    refute result =~ "MyApp.Consumer"
    refute result =~ "compile-time"
  end

  test "returns empty result when module has no dependents" do
    {:ok, _unused} =
      Modules.upsert(%{
        id: "Elixir.Unused",
        path: "/lib/unused.ex",
        checksum: "unused"
      })

    args = %{
      "moduleName" => "Elixir.Unused"
    }

    assert {:ok, result} = Codicil.MCP.Tools.ListModuleDependents.call(args)
    assert result =~ "No dependents found"
  end

  test "returns error when module not found" do
    args = %{
      "moduleName" => "Elixir.Ghost"
    }

    assert {:error, reason} = Codicil.MCP.Tools.ListModuleDependents.call(args)
    assert reason =~ "not found"
  end
end
