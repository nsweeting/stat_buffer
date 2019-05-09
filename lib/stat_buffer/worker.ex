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

  @doc """
  Increments a buffers key by the provided count.
  """
  @spec increment(buffer :: StatBuffer.t(), key :: any(), count :: integer()) :: :ok | :error
  def increment(buffer, key, count \\ 1, timeout \\ 5_000)

  def increment(buffer, key, count, timeout) when is_integer(count) do
    try do
      GenServer.call(buffer, {:increment, key, count}, timeout)
    catch
      :exit, reason ->
        Logger.error(inspect(reason))
        :error
    end
  end

  @doc """
  Same as `increment/3` except performs the operation asynchronously.
  """
  @spec async_increment(buffer :: StatBuffer.t(), key :: any(), count :: integer()) :: :ok
  def async_increment(buffer, key, count \\ 1)

  def async_increment(buffer, key, count) when is_integer(count) do
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

  def handle_call({:count, key}, _from, config) do
    count = do_lookup(config, key)
    {:reply, count, config, config.timeout()}
  end

  def handle_call({:increment, key, count}, _from, config) do
    do_increment(config, key, count)
    {:reply, :ok, config, config.timeout()}
  end

  @doc false
  @impl GenServer
  def handle_cast({:increment, key, count}, config) do
    do_increment(config, key, count)
    {:noreply, config, config.timeout()}
  end

  def handle_info({:flush, key}, config) do
    do_flush(config, key)
    {:noreply, config, config.timeout()}
  end

  @doc false
  @impl GenServer
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

  defp do_increment(config, key, count) do
    if :ets.update_counter(config.module, key, count, {0, 0}) == count do
      interval = do_calculate_interval(config)
      Process.send_after(self(), {:flush, key}, interval)
    end
  end

  defp do_calculate_interval(%{jitter: 0, interval: interval}) do
    interval
  end

  defp do_calculate_interval(%{jitter: jitter, interval: interval}) do
    interval + :rand.uniform(jitter)
  end

  defp do_lookup(buffer, key) do
    case :ets.lookup(buffer, key) do
      [{^key, count}] -> count
      _ -> nil
    end
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

  defp do_table_init(config) do
    case :ets.info(config.module) do
      :undefined -> :ets.new(config.module, [:public, :named_table, read_concurrency: true])
      _ -> :ok
    end
  end
end
