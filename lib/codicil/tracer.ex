defmodule Codicil.Tracer do
  # Compiler tracer that captures module compilation for code analysis.
  #
  # This module implements Elixir's tracer protocol by providing a `trace/2`
  # function that receives compiler events. The function must return `:ok`
  # and do minimal synchronous work to avoid slowing down compilation.
  #
  # The primary event of interest is `:on_module`, which fires when a module
  # is fully compiled. At that point, we can extract function information,
  # documentation, and relationships for analysis.
  @moduledoc false

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

    # Ignore if already started (can happen during recompilation or parallel tests)
    case DynamicSupervisor.start_child(Codicil.ModuleTracerSupervisor, child_spec) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        require Logger
        Logger.warning("Module already being traced: #{inspect(module)} in #{env.file}")
        :ok
    end
  end

  def trace({:import, _meta, module, _opts}, env) do
    dependent = hd(env.context_modules)
    Codicil.ModuleTracer.add_dependency(dependent, module, :compiler)
    :ok
  end

  def trace({:require, _meta, module, _opts}, env) do
    dependent = hd(env.context_modules)
    Codicil.ModuleTracer.add_dependency(dependent, module, :compiler)
    :ok
  end

  def trace({type, _meta, module, _opts}, env) when type in [:imported_macro, :remote_macro] do
    # use creates these events - track as compile-time dependency
    dependent = hd(env.context_modules)
    Codicil.ModuleTracer.add_dependency(dependent, module, :compiler)
    :ok
  end

  def trace(_event, _env) do
    :ok
  end
end
