defmodule Codicil.Tracer do
  @moduledoc """
  Compiler tracer that captures module compilation for code analysis.

  This module implements Elixir's tracer protocol by providing a `trace/2`
  function that receives compiler events. The function must return `:ok`
  and do minimal synchronous work to avoid slowing down compilation.

  The primary event of interest is `:on_module`, which fires when a module
  is fully compiled. At that point, we can extract function information,
  documentation, and relationships for analysis.
  """

  alias Codicil.Function

  @doc """
  Tracer callback function called by the compiler for each trace event.

  Returns `:ok` as required by the tracer protocol.
  """
  def trace({:on_module, bytecode, _opts}, env) do
    # Dispatch to background process for analysis
    Task.start(fn -> analyze_module(bytecode, env) end)

    :ok
  end

  def trace(_event, _env) do
    :ok
  end

  defp analyze_module(bytecode, env) do
    # Extract function information from disassembled bytecode
    {:beam_file, module, exports, _attributes, _compile_info, functions} =
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
        path: env.file,
        start_line: 0,  # TODO: Extract actual line numbers from source file
        end_line: 0,    # TODO: Extract actual line numbers from source file
        checksum: "TODO"
      }

      Function.create(attrs)
    end
  end
end
