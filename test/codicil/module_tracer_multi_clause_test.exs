defmodule Codicil.ModuleTracerMultiClauseTest do
  use ExUnit.Case, async: false

  alias Codicil.Db.Repo
  alias Codicil.Functions

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Allow other processes (like the tracer GenServer) to use this connection
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    # Clean up any existing data
    Repo.delete_all(Codicil.Db.Function)
    Repo.delete_all(Codicil.Db.Module)

    # Enable the tracer for this test
    Code.put_compiler_option(:tracers, [Codicil.Tracer])

    on_exit(fn ->
      # Restore tracer state
      Code.put_compiler_option(:tracers, [])
    end)

    :ok
  end

  test "tracer extracts all clauses from multi-clause functions" do
    # Create a temporary file with a multi-clause function
    test_file = "/tmp/multi_clause_tracer_test_#{System.unique_integer([:positive])}.ex"

    test_code = """
    defmodule MultiClauseTracerTest do
      # Process different input types
      def process(nil), do: :error
      def process([]), do: :empty
      def process([head | tail]) do
        [head | process(tail)]
      end

      # Another multi-clause function (must be used to avoid compiler warning)
      defp validate(:ok), do: true
      defp validate({:error, _}), do: false

      def run_validate(x), do: validate(x)
    end
    """

    File.write!(test_file, test_code)

    # Compile the module to trigger the tracer
    Code.compile_file(test_file)

    # Give the tracer time to process (tracer runs asynchronously)
    Process.sleep(500)

    # Verify the public function was extracted with all clauses
    process_fn = Functions.get_by_mfa({MultiClauseTracerTest, :process, 1})
    assert process_fn != nil, "process/1 function should be in database"

    # Check that all three clauses are present in the code
    assert process_fn.code =~ "def process(nil), do: :error",
           "First clause should be present"

    assert process_fn.code =~ "def process([]), do: :empty",
           "Second clause should be present"

    assert process_fn.code =~ "def process([head | tail]) do",
           "Third clause should be present"

    assert process_fn.code =~ "[head | process(tail)]",
           "Third clause body should be present"

    # Verify the private function was also extracted with all clauses
    validate_fn = Functions.get_by_mfa({MultiClauseTracerTest, :validate, 1})
    assert validate_fn != nil, "validate/1 function should be in database"

    # Check that both clauses are present
    assert validate_fn.code =~ "defp validate(:ok), do: true",
           "First private clause should be present"

    assert validate_fn.code =~ "defp validate({:error, _}), do: false",
           "Second private clause should be present"

    # Clean up
    File.rm(test_file)
  end

  test "tracer uses line number from first clause" do
    # Create a temporary file with a multi-clause function
    test_file = "/tmp/multi_clause_line_test_#{System.unique_integer([:positive])}.ex"

    test_code = """
    defmodule MultiClauseLineTest do
      # Line 2
      # Line 3
      def foo(1), do: :one
      def foo(2), do: :two
      def foo(_), do: :other
    end
    """

    File.write!(test_file, test_code)

    # Compile the module to trigger the tracer
    Code.compile_file(test_file)

    # Give the tracer time to process (tracer runs asynchronously)
    Process.sleep(500)

    # Verify the function was extracted
    foo_fn = Functions.get_by_mfa({MultiClauseLineTest, :foo, 1})
    assert foo_fn != nil

    # The line number should be from the first clause (line 4 in the heredoc, which is line 4 in the file)
    assert foo_fn.line == 4, "Line number should be from first clause"

    # Clean up
    File.rm(test_file)
  end
end
