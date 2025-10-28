defmodule Codicil.RateLimiter do
  # GenServer that rate-limits processing of functions for summarization and embedding generation.
  #
  # Enqueues functions during compilation and processes them asynchronously with
  # configurable delays between API calls to avoid throttling.
  @moduledoc false
  use GenServer

  alias Codicil.FunctionProcessor

  # BOILERPLATE & INITIALIZATION

  def start_link(opts \\ []) do
    {name, init_opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_opts, name: name)
  end

  @impl true
  def init(opts) do
    delay_ms = Keyword.get(opts, :delay_ms, 1000)
    llm_client = Keyword.get(opts, :llm_client, Application.get_env(:codicil, :llm_client))
    embeddings_client = Keyword.get(opts, :embeddings_client, Application.get_env(:codicil, :embeddings_client))

    if llm_client && embeddings_client do
      {:ok,
       %{
         queue: :queue.new(),
         delay_ms: delay_ms,
         processing: false,
         llm_client: llm_client,
         embeddings_client: embeddings_client
       }}
    else
      :ignore
    end
  end

  # API

  @doc """
  Enqueue a function for processing (summarization + embedding generation).
  Returns immediately, processing happens asynchronously.
  """
  @spec enqueue(pid() | __MODULE__, function :: Codicil.Db.Function.t()) :: :ok
  def enqueue(server \\ __MODULE__, function) do
    GenServer.call(server, {:enqueue, function})
  end

  # API IMPLEMENTATION

  defp enqueue_impl(function, _from, state) do
    # Add to queue
    new_queue = :queue.in(function, state.queue)
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
      {{:value, function}, remaining_queue} ->
        # Mark as processing
        new_state = %{state | queue: remaining_queue, processing: true}

        # Spawn task to process this function
        parent = self()

        # TODO: These tasks should be properly supervised
        Task.start_link(fn ->
          FunctionProcessor.process(function, state.llm_client, state.embeddings_client)
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

  # ROUTER

  @impl true
  def handle_call({:enqueue, function}, from, state) do
    enqueue_impl(function, from, state)
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
