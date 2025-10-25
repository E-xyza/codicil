defmodule Codicil.RateLimiter do
  # GenServer that rate-limits processing of functions for summarization and embedding generation.
  #
  # Enqueues functions during compilation and processes them asynchronously with
  # configurable delays between API calls to avoid throttling.
  @moduledoc false
  use GenServer

  alias Codicil.Functions
  alias Codicil.LLM.Summarizer
  alias Codicil.Embeddings

  # BOILERPLATE & INITIALIZATION

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    delay_ms = Keyword.get(opts, :delay_ms, 1000)

    {:ok,
     %{
       queue: :queue.new(),
       delay_ms: delay_ms,
       processing: false,
       llm_client: Application.get_env(:codicil, :llm_client),
       embeddings_client: Application.get_env(:codicil, :embeddings_client)
     }}
  end

  # API

  @doc """
  Enqueue a function for processing (summarization + embedding generation).
  Returns immediately, processing happens asynchronously.
  """
  @spec enqueue(function_info :: map()) :: :ok
  def enqueue(function_info) do
    enqueue(__MODULE__, function_info)
  end

  @spec enqueue(pid() | atom(), function_info :: map()) :: :ok
  def enqueue(pid, function_info) do
    GenServer.call(pid, {:enqueue, function_info})
  end

  # API IMPLEMENTATION

  defp enqueue_impl(function_info, _from, state) do
    # Add to queue
    new_queue = :queue.in(function_info, state.queue)
    new_state = %{state | queue: new_queue}

    # If not currently processing, start processing
    if not state.processing do
      {:reply, :ok, new_state, {:continue, :process_next}}
    else
      {:reply, :ok, new_state}
    end
  end

  defp process_next_impl(state) do
    case :queue.out(state.queue) do
      {{:value, function_info}, remaining_queue} ->
        # Mark as processing
        new_state = %{state | queue: remaining_queue, processing: true}

        # Spawn task to process this function
        parent = self()

        Task.start(fn ->
          process_function(function_info, state)
          # Wait before signaling done
          Process.sleep(state.delay_ms)
          GenServer.call(parent, :processing_done)
        end)

        {:noreply, new_state}

      {:empty, _queue} ->
        # Queue is empty, mark as not processing
        {:noreply, %{state | processing: false}}
    end
  end

  defp processing_done_impl(_from, state) do
    # Check if there are more items in queue
    if :queue.is_empty(state.queue) do
      {:reply, :ok, %{state | processing: false}}
    else
      {:reply, :ok, state, {:continue, :process_next}}
    end
  end

  # HELPER FUNCTIONS

  defp process_function(function_info, state) do
    # Generate summary if we have docs
    summary =
      case Map.get(function_info, :docs) do
        nil ->
          nil

        "" ->
          nil

        docs when is_binary(docs) ->
          case Summarizer.summarize_function(state.llm_client, function_info) do
            {:ok, %{summary: summary}} -> summary
            {:error, _reason} -> nil
          end
      end

    # Generate embedding if we have summary
    embedding =
      if summary do
        case Embeddings.embed(state.embeddings_client, summary, input_type: "passage") do
          {:ok, %{embedding: embedding}} ->
            # Convert to binary format for storage
            embedding
            |> Enum.map(&<<&1::float-32-native>>)
            |> IO.iodata_to_binary()

          {:error, _reason} ->
            nil
        end
      else
        nil
      end

    # Update function record with results
    case Functions.get(function_info.id) do
      nil ->
        :ok

      function ->
        attrs =
          %{}
          |> maybe_put(:summary, summary)
          |> maybe_put(:embedding, embedding)

        if map_size(attrs) > 0 do
          Functions.update(function, attrs)
        end
    end

    :ok
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # ROUTER

  @impl true
  def handle_call({:enqueue, function_info}, from, state) do
    enqueue_impl(function_info, from, state)
  end

  @impl true
  def handle_call(:processing_done, from, state) do
    processing_done_impl(from, state)
  end

  @impl true
  def handle_continue(:process_next, state) do
    process_next_impl(state)
  end
end
