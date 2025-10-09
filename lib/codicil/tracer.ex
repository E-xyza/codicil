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

  @doc """
  Tracer callback function called by the compiler for each trace event.

  Returns `:ok` as required by the tracer protocol.
  """
  def trace({:on_module, bytecode, _opts}, _env) do
    # Extract module name from bytecode
    {:beam_file, module, _exports, _attributes, _compile_info, _functions} =
      :beam_disasm.file(bytecode)

    # Send completion event to the ModuleTracer (via Registry)
    Codicil.ModuleTracer.complete(module, bytecode)

    :ok
  end

  def trace(:defmodule, env) do
    module = hd(env.context_modules)

    # Start a ModuleTracer GenServer for this module, registering it via the Registry
    child_spec = %{
      id: Codicil.ModuleTracer,
      start: {Codicil.ModuleTracer, :start_link, [module, env.file]},
      restart: :temporary
    }

    {:ok, _pid} = DynamicSupervisor.start_child(
      Codicil.ModuleTracerSupervisor,
      child_spec
    )

    :ok
  end

  def trace(_event, _env) do
    :ok
  end
end
