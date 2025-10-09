defmodule Codicil.Tracer do
  @moduledoc """
  Compiler tracer that captures compilation events for code analysis.

  This module implements Elixir's tracer protocol by providing a `trace/2`
  function that receives compiler events. The function must return `:ok`
  and do minimal synchronous work to avoid slowing down compilation.
  """

  @doc """
  Tracer callback function called by the compiler for each trace event.

  Returns `:ok` as required by the tracer protocol.
  """
  def trace(_event, _env) do
    :ok
  end
end
