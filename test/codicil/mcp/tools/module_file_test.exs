defmodule Codicil.MCP.Tools.ModuleFileTest do
  use ExUnit.Case, async: false

  alias Codicil.Db.Repo
  alias Codicil.Modules

  setup do
    # Sandbox for test isolation
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Create test modules
    {:ok, module1} =
      Modules.upsert(%{
        id: "Elixir.MyApp.User",
        path: "/lib/my_app/user.ex",
        checksum: "abc123"
      })

    {:ok, module2} =
      Modules.upsert(%{
        id: "Elixir.MyApp.Order",
        path: "/lib/my_app/order.ex",
        checksum: "def456"
      })

    %{module1: module1, module2: module2}
  end

  test "returns file path for existing module", %{module1: module1} do
    args = %{"moduleName" => "Elixir.MyApp.User"}

    assert {:ok, path} = Codicil.MCP.Tools.ModuleFile.call(args)
    assert path == module1.path
  end

  test "returns file path for another module", %{module2: module2} do
    args = %{"moduleName" => "Elixir.MyApp.Order"}

    assert {:ok, path} = Codicil.MCP.Tools.ModuleFile.call(args)
    assert path == module2.path
  end

  test "returns error when module not found" do
    args = %{"moduleName" => "Elixir.NonExistent"}

    assert {:error, reason} = Codicil.MCP.Tools.ModuleFile.call(args)
    assert reason =~ "not found"
  end
end
