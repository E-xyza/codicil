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
    # Extract module name from bytecode
    {:ok, {module, _}} = :beam_lib.chunks(bytecode, [:attributes])

    # Dispatch to background process for analysis
    Task.start(fn -> analyze_module(module, bytecode, env) end)

    :ok
  end

  def trace(_event, _env) do
    :ok
  end

  defp analyze_module(module, _bytecode, env) do
    # Use runtime reflection to get function list
    # The module is already loaded at this point
    functions = module.__info__(:functions)

    # Extract function metadata using Code.fetch_docs
    docs =
      case Code.fetch_docs(module) do
        {:docs_v1, _anno, _beam_language, _format, _module_doc, _metadata, docs} -> docs
        {:error, _} -> []
      end

    # Store functions in database
    for {name, arity} <- functions do
      # Find the doc entry for this function
      doc_entry = Enum.find(docs, fn
        {{:function, ^name, ^arity}, _, _, _, _} -> true
        _ -> false
      end)

      line =
        case doc_entry do
          {{:function, _, _}, anno, _, _, _} -> Keyword.get(anno, :line, 1)
          nil -> 1
        end

      Function.create(%{
        name: Atom.to_string(name),
        module: Atom.to_string(module),
        arity: arity,
        path: env.file,
        start_line: line,
        end_line: line,  # TODO: Calculate actual end line from AST
        checksum: "TODO"  # TODO: Calculate checksum
      })
    end
  end
end
