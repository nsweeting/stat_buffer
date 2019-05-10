defmodule StatBuffer.Worker do
  @moduledoc false

  use GenServer

  require Logger

  alias StatBuffer.FlusherSupervisor

  ################################
  # Public API
  ################################

  @doc false
  def child_spec({buffer, opts}) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [buffer, opts]},
      restart: :transient
    }
  end

  @doc """
  Starts a buffer worker process.
  """
  @spec start_link(buffer :: StatBuffer.t(), keyword()) :: GenServer.on_start()
  def start_link(buffer, opts) do
    GenServer.start_link(__MODULE__, {buffer, opts}, name: buffer)
  end

  @doc false
  def increment(buffer, key) do
    increment(buffer, key, 1)
  end

  @doc """
  Increments a buffers key by the provided count.
  """
  @spec increment(buffer :: StatBuffer.t(), key :: any(), count :: integer()) :: :ok | :error
  def increment(buffer, key, count) when is_integer(count) do
    try do
      do_increment(buffer, key, count)
    rescue
      ArgumentError -> :error
    end
  end

  @deprecated "Use increment/3 instead"
  @spec increment(buffer :: StatBuffer.t(), key :: any(), count :: integer(), timeout()) ::
          :ok | :error
  def increment(buffer, key, count, _timeout) do
    increment(buffer, key, count)
  end

  @spec async_increment(buffer :: StatBuffer.t(), key :: any(), count :: integer()) ::
          :ok | :error
  def async_increment(buffer, key, count) do
    GenServer.cast(buffer, {:increment, key, count})
  end

  @doc """
  Asynchronously flushes a buffers key.
  """
  @spec flush(buffer :: StatBuffer.t(), key :: any()) :: :ok
  def flush(buffer, key) do
    GenServer.call(buffer, {:flush, key})
  end

  @doc """
  Returns the current count of a buffers key.
  """
  @spec count(buffer :: StatBuffer.t(), key :: any()) :: integer() | nil
  def count(buffer, key) do
    do_lookup(buffer, key)
  end

  ################################
  # GenServer Callbacks
  ################################

  @doc false
  @impl GenServer
  def init({buffer, opts}) do
    config = do_config(buffer, opts)
    do_table_init(config)

    {:ok, config, config.timeout()}
  end

  @doc false
  @impl GenServer
  def handle_call({:flush, key}, _from, config) do
    do_flush(config, key)
    {:reply, :ok, config, config.timeout()}
  end

  @doc false
  @impl GenServer
  def handle_cast({:schedule_flush, key}, config) do
    do_schedule_flush(key, config)
    {:noreply, config, config.timeout()}
  end

  def handle_cast({:increment, key, count}, config) do
    do_increment(config.module, key, count)
    {:noreply, config, config.timeout()}
  end

  @doc false
  @impl GenServer
  def handle_info({:flush, key}, config) do
    do_flush(config, key)
    {:noreply, config, config.timeout()}
  end

  def handle_info(:timeout, config) do
    {:noreply, config, :hibernate}
  end

  ################################
  # Private Functions
  ################################

  defp do_config(buffer, opts) do
    [module: buffer]
    |> Keyword.merge(opts)
    |> Enum.into(%{})
  end

  defp do_increment(buffer, key, count) do
    if :ets.update_counter(buffer, key, count, {0, 0}) == count do
      GenServer.cast(buffer, {:schedule_flush, key})
    end

    :ok
  end

  defp do_schedule_flush(key, config) do
    interval = do_calculate_interval(config)
    Process.send_after(self(), {:flush, key}, interval)
  end

  defp do_calculate_interval(%{jitter: 0, interval: interval}) do
    interval
  end

  defp do_calculate_interval(%{jitter: jitter, interval: interval}) do
    interval + :rand.uniform(jitter)
  end

  defp do_flush(config, key) do
    case :ets.take(config.module, key) do
      [{^key, count}] ->
        opts = [backoff: config.backoff]
        FlusherSupervisor.start_flusher(config.module, key, count, opts)

      _ ->
        :error
    end
  end

  defp do_lookup(buffer, key) do
    case :ets.lookup(buffer, key) do
      [{^key, count}] -> count
      _ -> nil
    end
  end

  defp do_table_init(config) do
    case :ets.info(config.module) do
      :undefined ->
        :ets.new(config.module, [
          :public,
          :named_table,
          write_concurrency: true,
          read_concurrency: true
        ])

      _ ->
        :ok
    end
  end
end
