defmodule StatBuffer.Worker do
  @moduledoc false

  require Logger

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
    GenServer.start_link(StatBuffer.WorkerServer, buffer, name: buffer)
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
end
