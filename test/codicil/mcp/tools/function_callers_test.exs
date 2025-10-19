defmodule Codicil.MCP.Tools.FunctionCallersTest do
  use ExUnit.Case, async: true

  alias Codicil.Db.Repo
  alias Codicil.Functions

  setup do
    # Sandbox for test isolation
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Create target function
    {_status, target} =
      Functions.upsert(%{
        name: :target_function,
        module: MyModule,
        arity: 1,
        exported: true,
        path: "/lib/my_module.ex",
        line: 10,
        checksum: "abc123"
      })

    # Create caller functions
    {_status, caller1} =
      Functions.upsert(%{
        name: :caller_one,
        module: CallerModule,
        arity: 0,
        exported: true,
        path: "/lib/caller_module.ex",
        line: 5,
        checksum: "def456"
      })

    {_status, caller2} =
      Functions.upsert(%{
        name: :caller_two,
        module: AnotherCaller,
        arity: 2,
        exported: false,
        path: "/lib/another_caller.ex",
        line: 15,
        checksum: "ghi789"
      })

    # Create function calls
    Functions.add_call(caller1, target)
    Functions.add_call(caller2, target)

    %{target: target, caller1: caller1, caller2: caller2}
  end

  test "returns functions that call the target function", %{target: _target} do
    args = %{
      "functionName" => "target_function",
      "moduleName" => "Elixir.MyModule",
      "arity" => 1
    }

    assert {:ok, result} = Codicil.MCP.Tools.FunctionCallers.call(args)
    assert result =~ "caller_one"
    assert result =~ "CallerModule"
    assert result =~ "caller_two"
    assert result =~ "AnotherCaller"
  end

  test "returns empty result when no callers exist" do
    # Create a function with no callers
    {_status, _lonely} =
      Functions.upsert(%{
        name: :lonely_function,
        module: Lonely,
        arity: 0,
        exported: true,
        path: "/lib/lonely.ex",
        line: 1,
        checksum: "lonely"
      })

    args = %{
      "functionName" => "lonely_function",
      "moduleName" => "Elixir.Lonely",
      "arity" => 0
    }

    assert {:ok, result} = Codicil.MCP.Tools.FunctionCallers.call(args)
    assert result =~ "No callers found"
  end

  test "returns error when function not found" do
    args = %{
      "functionName" => "nonexistent",
      "moduleName" => "Elixir.Ghost",
      "arity" => 0
    }

    assert {:error, reason} = Codicil.MCP.Tools.FunctionCallers.call(args)
    assert reason =~ "not found"
  end
end
