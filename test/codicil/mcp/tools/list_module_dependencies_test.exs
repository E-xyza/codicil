defmodule Codicil.MCP.Tools.ListModuleDependenciesTest do
  use ExUnit.Case, async: false

  alias Codicil.Db.Repo
  alias Codicil.Modules

  setup do
    # Sandbox for test isolation
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Create source module
    {:ok, source} =
      Modules.upsert(%{
        id: "Elixir.MyApp.MainModule",
        path: "/lib/my_app/main_module.ex",
        checksum: "abc123"
      })

    # Create dependency modules
    {:ok, dep1} =
      Modules.upsert(%{
        id: "Elixir.MyApp.HelperModule",
        path: "/lib/my_app/helper_module.ex",
        checksum: "def456"
      })

    {:ok, dep2} =
      Modules.upsert(%{
        id: "Elixir.SomeLib.Utility",
        path: "/deps/some_lib/lib/utility.ex",
        checksum: "ghi789"
      })

    # Create compile-time dependencies (import, require, use)
    Modules.create_dependency(%{
      dependent_id: source.id,
      dependency_id: dep1.id,
      type: :compiler
    })

    # Create runtime dependency (function calls)
    Modules.create_dependency(%{
      dependent_id: source.id,
      dependency_id: dep2.id,
      type: :runtime
    })

    %{source: source, dep1: dep1, dep2: dep2}
  end

  test "returns all dependencies for a module", %{source: _source} do
    args = %{
      "moduleName" => "Elixir.MyApp.MainModule"
    }

    assert {:ok, result} = Codicil.MCP.Tools.ListModuleDependencies.call(args)
    assert result =~ "MyApp.HelperModule"
    assert result =~ "SomeLib.Utility"
    assert result =~ "compile-time"
    assert result =~ "runtime"
  end

  test "filters by compile-time dependencies only" do
    args = %{
      "moduleName" => "Elixir.MyApp.MainModule",
      "type" => "compiler"
    }

    assert {:ok, result} = Codicil.MCP.Tools.ListModuleDependencies.call(args)
    assert result =~ "MyApp.HelperModule"
    assert result =~ "compile-time"
    refute result =~ "SomeLib.Utility"
    refute result =~ "runtime"
  end

  test "filters by runtime dependencies only" do
    args = %{
      "moduleName" => "Elixir.MyApp.MainModule",
      "type" => "runtime"
    }

    assert {:ok, result} = Codicil.MCP.Tools.ListModuleDependencies.call(args)
    assert result =~ "SomeLib.Utility"
    assert result =~ "runtime"
    refute result =~ "MyApp.HelperModule"
    refute result =~ "compile-time"
  end

  test "returns empty result when module has no dependencies" do
    {:ok, _lonely} =
      Modules.upsert(%{
        id: "Elixir.Lonely",
        path: "/lib/lonely.ex",
        checksum: "lonely"
      })

    args = %{
      "moduleName" => "Elixir.Lonely"
    }

    assert {:ok, result} = Codicil.MCP.Tools.ListModuleDependencies.call(args)
    assert result =~ "No dependencies found"
  end

  test "returns error when module not found" do
    args = %{
      "moduleName" => "Elixir.Ghost"
    }

    assert {:error, reason} = Codicil.MCP.Tools.ListModuleDependencies.call(args)
    assert reason =~ "not found"
  end
end
