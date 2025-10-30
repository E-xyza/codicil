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

  require Logger

  def trace(event, env) do
    if Application.get_env(:codicil, :skip_startup) do
      :ok
    else
      do_trace(event, env)
    end
  end

  defp do_trace({:on_module, bytecode, _opts}, _env) do
    ensure_started()

    # Extract module name from bytecode
    {:beam_file, module, _exports, _attributes, _compile_info, _functions} =
      :beam_disasm.file(bytecode)

    # Send completion event to the ModuleTracer (via Registry)
    Codicil.ModuleTracer.complete(module, bytecode)

    :ok
  end

  defp do_trace(:defmodule, env) do
    ensure_started()

    # Use env.module which is always the module being compiled
    module = env.module

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
        Logger.warning("Module already being traced: #{inspect(module)} in #{env.file}")
        :ok
    end
  end

  defp do_trace({:import, _meta, module, _opts}, env) when not is_nil(env.module) do
    ensure_started()

    Codicil.ModuleTracer.add_dependency(env.module, module, :compiler)

    :ok
  end

  defp do_trace({:require, _meta, module, _opts}, env) when not is_nil(env.module) do
    ensure_started()

    Codicil.ModuleTracer.add_dependency(env.module, module, :compiler)

    :ok
  end

  defp do_trace({type, _meta, module, _opts}, env)
       when type in [:imported_macro, :remote_macro] and not is_nil(env.module) do
    ensure_started()

    # use creates these events - track as compile-time dependency
    Codicil.ModuleTracer.add_dependency(env.module, module, :compiler)

    :ok
  end

  defp do_trace(_event, _env) do
    :ok
  end

  # Ensure Codicil application is started before using its infrastructure
  # Cache the result in application env for fast subsequent checks
  defp ensure_started do
    with true <- !Application.get_env(:codicil, :started),
        {:error, reason} <- Application.ensure_all_started(:codicil) do
        startup_fail(reason)
    end
    Application.put_env(:codicil, :started, true)
  end

  defp startup_fail(reason) do
    if System.get_env("CODICIL_LLM_PROVIDER", "") != "" do
      raise "Failed to start Codicil (#{inspect reason})"
    else
      raise """
      CODICIL_LLM_PROVIDER environment variable is not set.

      Please set it to one of: openai, anthropic, cohere, google, grok

      Example:
        export CODICIL_LLM_PROVIDER=openai
        export OPENAI_API_KEY=your_api_key
      """
    end
  end
end
