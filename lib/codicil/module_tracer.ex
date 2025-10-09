defmodule Codicil.ModuleTracer do
  @moduledoc """
  GenServer that tracks compilation of a single module.

  Started when :defmodule event is received, stores compilation info,
  and processes the module when :on_module event completes it.
  """
  use GenServer

  # BOILERPLATE & INITIALIZATION

  def start_link(module_name, file_path) do
    GenServer.start_link(
      __MODULE__,
      {module_name, file_path},
      name: via(module_name)
    )
  end

  @impl true
  def init({module_name, file_path}) do
    {:ok, %{module: module_name, file: file_path}}
  end

  # API

  @spec complete(module_name :: module(), bytecode :: binary()) :: :ok
  def complete(module_name, bytecode) do
    GenServer.cast(via(module_name), {:complete, bytecode})
  end

  # API IMPLEMENTATION

  defp complete_impl(bytecode, %{module: module, file: file} = state) do
    alias Codicil.Function

    # Extract function information from disassembled bytecode
    {:beam_file, _module, exports, _attributes, _compile_info, functions} =
      :beam_disasm.file(bytecode)

    # Build set of exported function names/arities (excluding compiler-generated functions)
    exported_set =
      exports
      |> Enum.reject(fn {name, _arity, _label} ->
        name in [:__info__, :module_info] or String.starts_with?(Atom.to_string(name), "-")
      end)
      |> Enum.map(fn {name, arity, _label} -> {name, arity} end)
      |> MapSet.new()

    # Extract all functions (excluding compiler-generated functions)
    all_functions =
      functions
      |> Enum.reject(fn {:function, name, _arity, _label, _code} ->
        name in [:__info__, :module_info] or String.starts_with?(Atom.to_string(name), "-")
      end)
      |> Enum.map(fn {:function, name, arity, _label, _code} ->
        {name, arity}
      end)

    # Store functions in database
    for {name, arity} <- all_functions do
      exported = MapSet.member?(exported_set, {name, arity})

      attrs = %{
        name: Atom.to_string(name),
        module: Atom.to_string(module),
        arity: arity,
        exported: exported,
        path: file,
        start_line: 0,  # TODO: Extract actual line numbers from source file
        end_line: 0,    # TODO: Extract actual line numbers from source file
        checksum: "TODO"
      }

      Function.create(attrs)
    end

    # Stop the GenServer after processing
    {:stop, :normal, state}
  end

  # HELPER FUNCTIONS

  defp via(module_name) do
    {:via, Registry, {Codicil.ModuleTracerRegistry, module_name}}
  end

  # ROUTER

  @impl true
  def handle_cast({:complete, bytecode}, state) do
    complete_impl(bytecode, state)
  end
end
