defmodule StatBuffer.Worker do
  @moduledoc false

  @doc """
  Starts a buffer worker process.
  """
  @spec start_link(buffer :: StatBuffer.t()) :: GenServer.on_start()
  def start_link(buffer) do
    GenServer.start_link(StatBuffer.WorkerServer, buffer, name: via_tuple(buffer))
  end

  @doc false
  def child_spec(buffer) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [buffer]},
      restart: :transient
    }
  end

  @doc """
  Increments a buffers key by the provided count.

  ## Parameters

    - buffer: A buffer module.
    - key: Any valid term.
    - count: An integer count. Defaults to 1.
  """
  @spec increment(buffer :: StatBuffer.t(), key :: any(), count :: integer()) :: :ok | no_return()
  def increment(buffer, key, count \\ 1)

  def increment(buffer, key, count) when is_integer(count) do
    GenServer.call(via_tuple(buffer), {:increment, key, count})
  end

  def increment(_buffer, _key, _count) do
    raise ArgumentError, "count must be an integer"
  end

  @doc """
  Same as `increment/3` except performs the operation asynchronously.
  """
  @spec async_increment(buffer :: StatBuffer.t(), key :: any(), count :: integer()) :: :ok | no_return()
  def async_increment(buffer, key, count \\ 1)

  def async_increment(buffer, key, count) when is_integer(count) do
    GenServer.cast(via_tuple(buffer), {:increment, key, count})
  end

  def async_increment(_buffer, _key, _count) do
    raise ArgumentError, "count must be an integer"
  end

  @doc """
  Asynchronously flushes a buffers key.

  ## Parameters

    - buffer: A buffer module.
    - key: Any valid term.
  """
  @spec flush(buffer :: StatBuffer.t(), key :: any()) :: :ok | no_return()
  def flush(buffer, key) do
    GenServer.call(via_tuple(buffer), {:flush, key})
  end

  @doc """
  Returns the current count of a buffers key.

  ## Parameters

    - buffer: A buffer module.
    - key: Any valid term.
  """
  @spec count(buffer :: StatBuffer.t(), key :: any()) :: integer() | nil | no_return()
  def count(buffer, key) do
    GenServer.call(via_tuple(buffer), {:count, key})
  end

  defp via_tuple(buffer) do
    {:via, Registry, {StatBuffer.WorkerRegistry, buffer}}
  end
end
