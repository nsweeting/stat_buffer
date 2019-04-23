defmodule StatBuffer.Worker do
  @moduledoc false

  use GenServer

  require Logger

  alias :ets, as: ETS

  ################################
  # Public API
  ################################

  @doc false
  def child_spec(buffer) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [buffer]},
      restart: :transient
    }
  end

  @doc """
  Starts a buffer worker process.
  """
  @spec start_link(buffer :: StatBuffer.t()) :: GenServer.on_start()
  def start_link(buffer) do
    GenServer.start_link(__MODULE__, buffer, name: buffer)
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
  @spec async_increment(buffer :: StatBuffer.t(), key :: any(), count :: integer()) ::
          :ok | no_return()
  def async_increment(buffer, key, count \\ 1)

  def async_increment(buffer, key, count) when is_integer(count) do
    GenServer.cast(buffer, {:increment, key, count})
  end

  @doc """
  Asynchronously flushes a buffers key.
  """
  @spec flush(buffer :: StatBuffer.t(), key :: any()) :: :ok | no_return()
  def flush(buffer, key) do
    GenServer.call(buffer, {:flush, key})
  end

  @doc """
  Returns the current count of a buffers key.
  """
  @spec count(buffer :: StatBuffer.t(), key :: any()) :: integer() | nil | no_return()
  def count(buffer, key) do
    GenServer.call(buffer, {:count, key})
  end

  ################################
  # GenServer Callbacks
  ################################

  @doc false
  @impl GenServer
  def init(buffer) do
    do_table_init(buffer)
    {:ok, buffer, buffer.timeout()}
  end

  @doc false
  @impl GenServer
  def handle_call({:flush, key}, _from, buffer) do
    do_flush(buffer, key)
    {:reply, :ok, buffer, buffer.timeout()}
  end

  def handle_call({:count, key}, _from, buffer) do
    count = do_lookup(buffer, key)
    {:reply, count, buffer, buffer.timeout()}
  end

  def handle_call({:increment, key, count}, _from, buffer) do
    do_increment(buffer, key, count)
    {:reply, :ok, buffer, buffer.timeout()}
  end

  @doc false
  @impl GenServer
  def handle_cast({:increment, key, count}, buffer) do
    do_increment(buffer, key, count)
    {:noreply, buffer, buffer.timeout()}
  end

  def handle_info({:flush, key}, buffer) do
    do_flush(buffer, key)
    {:noreply, buffer, buffer.timeout()}
  end

  @doc false
  @impl GenServer
  def handle_info(:timeout, buffer) do
    {:noreply, buffer, :hibernate}
  end

  ################################
  # Private Functions
  ################################

  defp do_increment(buffer, key, count) do
    if ETS.update_counter(buffer, key, count, {0, 0}) == count do
      Process.send_after(self(), {:flush, key}, buffer.interval())
    end
  end

  defp do_lookup(buffer, key) do
    case ETS.lookup(buffer, key) do
      [{^key, count}] -> count
      _ -> nil
    end
  end

  defp do_flush(buffer, key) do
    case ETS.take(buffer, key) do
      [{^key, count}] -> StatBuffer.Flusher.async_run(buffer, key, count)
      _ -> :error
    end
  end

  defp do_table_init(buffer) do
    case ETS.info(buffer) do
      :undefined -> :ets.new(buffer, [:public, :named_table])
      _ -> buffer
    end
  end
end
