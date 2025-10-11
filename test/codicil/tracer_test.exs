defmodule Codicil.TracerTest do
  use ExUnit.Case, async: true

  alias Codicil.Functions
  alias Codicil.Db.Repo

  setup do
    # Start a sandbox transaction for isolated testing
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "trace/2" do
    test "handles :on_module event with simple add_one function" do
      # Compile a module from a file
      example_path = Path.join(__DIR__, "tracer_examples/add_one_module.ex")
      [{module, _}] = Code.compile_file(example_path)

      # Give the background task time to complete
      Process.sleep(100)

      # Should create a Function database entry
      assert function = Functions.get_by_mfa({AddOneModule, :add_one, 1})
      assert function.name == "add_one"
      assert function.module == "Elixir.AddOneModule"
      assert function.arity == 1
      assert function.exported
      assert function.path == example_path
      assert function.line == 2

      # Clean up
      :code.purge(module)
      :code.delete(module)
    end

    test "marks private functions as exported: false" do
      # Compile a module with both public and private functions
      example_path = Path.join(__DIR__, "tracer_examples/private_function_module.ex")
      [{module, _}] = Code.compile_file(example_path)

      # Give the background task time to complete
      Process.sleep(100)

      # Public function should be exported
      assert public_fn = Functions.get_by_mfa({PrivateFunctionModule, :public_function, 1})
      assert public_fn.exported

      # Private function should not be exported
      assert private_fn = Functions.get_by_mfa({PrivateFunctionModule, :private_helper, 1})
      refute private_fn.exported

      # public_function should call private_helper
      calls = Functions.list_calls(public_fn)
      assert length(calls) == 1
      assert hd(calls).id == private_fn.id

      # private_helper should be called by public_function
      callers = Functions.list_called_by(private_fn)
      assert length(callers) == 1
      assert hd(callers).id == public_fn.id

      # Clean up
      :code.purge(module)
      :code.delete(module)
    end

    test "stores function documentation in docs field" do
      # Compile a module with @doc attributes
      example_path = Path.join(__DIR__, "tracer_examples/documented_module.ex")
      [{module, _}] = Code.compile_file(example_path)

      # Give the background task time to complete
      Process.sleep(100)

      # Function with @doc should have docs
      assert documented_fn = Functions.get_by_mfa({DocumentedModule, :double, 1})
      assert documented_fn.docs == "Multiplies a number by two."

      # Function with @doc false should have nil docs
      assert hidden_fn = Functions.get_by_mfa({DocumentedModule, :hidden_function, 1})
      assert hidden_fn.docs == nil

      # Function without @doc should have nil docs
      assert undocumented_fn = Functions.get_by_mfa({DocumentedModule, :undocumented_function, 1})
      assert undocumented_fn.docs == nil

      # Clean up
      :code.purge(module)
      :code.delete(module)
    end

    test "creates placeholders for remote function calls" do
      # Compile a module that calls external functions
      example_path = Path.join(__DIR__, "tracer_examples/remote_calls_module.ex")
      [{module, _}] = Code.compile_file(example_path)

      # Give the background task time to complete
      Process.sleep(100)

      # Verify the functions were created
      assert call_external = Functions.get_by_mfa({RemoteCallsModule, :call_external, 1})
      assert call_external.exported

      assert call_string = Functions.get_by_mfa({RemoteCallsModule, :call_string_functions, 1})
      assert call_string.exported

      # Check that remote calls created placeholders
      assert [
        %{module: "Elixir.Enum", name: "count", arity: 1, parsed: nil}
      ] = call_external
      |> Functions.list_calls()
      |> Enum.sort_by(&{&1.module, &1.name})

      assert [
        %{module: "Elixir.String", name: "trim", arity: 1, parsed: nil},
        %{module: "Elixir.String", name: "upcase", arity: 1, parsed: nil}
      ] = call_string
      |> Functions.list_calls()
      |> Enum.sort_by(&{&1.module, &1.name})

      # Clean up
      :code.purge(module)
      :code.delete(module)
    end

    test "tracks module dependencies (import, require, use)" do
      # Compile a module that has various dependencies
      example_path = Path.join(__DIR__, "tracer_examples/module_with_dependencies.ex")
      [{module, _}] = Code.compile_file(example_path)

      # Give the background task time to complete
      Process.sleep(100)

      # Verify the module was created
      assert module_record = Codicil.Modules.get(ModuleWithDependencies)
      assert module_record.id == "Elixir.ModuleWithDependencies"

      # Get compile-time dependencies
      dependencies = Codicil.Modules.list_compile_dependencies(module_record)

      # Should have compile-time dependencies on String (import), Logger (require), and GenServer (use)
      assert ["Elixir.GenServer", "Elixir.Logger", "Elixir.String"] =
               Enum.map(dependencies, & &1.id) |> Enum.sort()

      # Clean up
      :code.purge(module)
      :code.delete(module)
    end
  end
end
