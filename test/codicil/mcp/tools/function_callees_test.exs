defmodule Codicil.MCP.Tools.FunctionCalleesTest do
  use ExUnit.Case, async: false

  alias Codicil.Db.Repo
  alias Codicil.Functions

  setup do
    # Sandbox for test isolation
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Process.sleep(100)

    # Create source function
    {_status, source} =
      Functions.upsert(%{
        name: :source_function,
        module: MyModule,
        arity: 0,
        exported: true,
        path: "/lib/my_module.ex",
        line: 5,
        checksum: "abc123"
      })

    # Create callee functions (functions called by source)
    {_status, callee1} =
      Functions.upsert(%{
        name: :helper_one,
        module: HelperModule,
        arity: 1,
        exported: false,
        path: "/lib/helper_module.ex",
        line: 10,
        checksum: "def456"
      })

    {_status, callee2} =
      Functions.upsert(%{
        name: :helper_two,
        module: AnotherHelper,
        arity: 2,
        exported: true,
        path: "/lib/another_helper.ex",
        line: 20,
        checksum: "ghi789"
      })

    # Create function calls (source calls callee1 and callee2)
    Functions.add_call(source, callee1)
    Functions.add_call(source, callee2)

    %{source: source, callee1: callee1, callee2: callee2}
  end

  test "returns functions called by the source function", %{source: _source} do
    args = %{
      "functionName" => "source_function",
      "moduleName" => "Elixir.MyModule",
      "arity" => 0
    }

    assert {:ok, result} = Codicil.MCP.Tools.FunctionCallees.call(args)
    assert result =~ "helper_one"
    assert result =~ "HelperModule"
    assert result =~ "helper_two"
    assert result =~ "AnotherHelper"
  end

  test "returns empty result when function calls nothing" do
    # Create a function that doesn't call anything
    {_status, _isolated} =
      Functions.upsert(%{
        name: :isolated_function,
        module: Isolated,
        arity: 0,
        exported: true,
        path: "/lib/isolated.ex",
        line: 1,
        checksum: "isolated"
      })

    args = %{
      "functionName" => "isolated_function",
      "moduleName" => "Elixir.Isolated",
      "arity" => 0
    }

    assert {:ok, result} = Codicil.MCP.Tools.FunctionCallees.call(args)
    assert result =~ "No callees found"
  end

  test "returns error when function not found" do
    args = %{
      "functionName" => "nonexistent",
      "moduleName" => "Elixir.Ghost",
      "arity" => 0
    }

    assert {:error, reason} = Codicil.MCP.Tools.FunctionCallees.call(args)
    assert reason =~ "not found"
  end
end
