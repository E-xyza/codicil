defmodule Codicil.MCP.Tools.FunctionCodeTest do
  use ExUnit.Case, async: false

  alias Codicil.Db.Repo
  alias Codicil.Functions
  alias Codicil.Modules

  setup do
    # Sandbox for test isolation
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Create a test file with imports/aliases
    test_file = "/tmp/function_code_test_#{System.unique_integer([:positive])}.ex"

    test_code = """
    defmodule TestModule do
      use GenServer
      alias Some.Other.Module
      import Enum, only: [map: 2]

      def test_function(arg1, arg2) do
        arg1 + arg2
      end

      defp private_function do
        :ok
      end
    end
    """

    File.write!(test_file, test_code)

    # Create module record
    {:ok, module} =
      Modules.upsert(%{
        id: "Elixir.TestModule",
        path: test_file,
        checksum: "test123"
      })

    # Create function record
    {:ok, function} =
      Functions.upsert(%{
        module: "Elixir.TestModule",
        name: "test_function",
        arity: 2,
        exported: true,
        path: test_file,
        line: 6,
        code: "def test_function(arg1, arg2) do\n  arg1 + arg2\nend",
        checksum: "func123"
      })

    on_exit(fn -> File.rm(test_file) end)

    %{module: module, function: function, test_file: test_file}
  end

  test "returns function code with module directives" do
    args = %{
      "moduleName" => "Elixir.TestModule",
      "functionName" => "test_function",
      "arity" => 2
    }

    assert {:ok, code} = Codicil.MCP.Tools.FunctionCode.call(args)

    # Should include directives
    assert code =~ "use GenServer"
    assert code =~ "alias Some.Other.Module"
    assert code =~ "import Enum"

    # Should include function code
    assert code =~ "def test_function(arg1, arg2)"
    assert code =~ "arg1 + arg2"
  end

  test "returns error when function not found" do
    args = %{
      "moduleName" => "Elixir.TestModule",
      "functionName" => "nonexistent",
      "arity" => 0
    }

    assert {:error, reason} = Codicil.MCP.Tools.FunctionCode.call(args)
    assert reason =~ "not found"
  end

  test "returns error when module not found" do
    args = %{
      "moduleName" => "Elixir.NonExistent",
      "functionName" => "test",
      "arity" => 0
    }

    assert {:error, reason} = Codicil.MCP.Tools.FunctionCode.call(args)
    assert reason =~ "not found"
  end
end
