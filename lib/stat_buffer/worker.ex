defmodule StatBuffer.Worker do
  @moduledoc false

  alias StatBuffer.State
  alias StatBuffer.WorkerRegistry
  alias StatBuffer.WorkerSupervisor
  alias StatBuffer.WorkerServer

  @doc """
  Starts a buffer worker process.
  """
  @spec start_link(state :: StatBuffer.State.t()) :: GenServer.on_start()
  def start_link(state) do
    GenServer.start_link(WorkerServer, state, name: via_tuple(state))
  end

  @doc false
  def child_spec(state) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [state]},
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
  @spec increment(buffer :: StatBuffer.t(), key :: any, count :: integer) :: :ok | no_return
  def increment(buffer, key, count \\ 1)

  def increment(buffer, key, count) when is_integer(count) do
    if WorkerRegistry.key_exists?(buffer, key) do
      GenServer.call(via_tuple(buffer, key), {:increment, count})
    else
      new_worker(buffer, key, count)
    end
  end

  def increment(_buffer, _key, _count) do
    raise ArgumentError, "count must be an integer"
  end

  @doc """
  Same as `increment/3` except performs the operation asynchronously.
  """
  @spec async_increment(buffer :: StatBuffer.t(), key :: any, count :: integer) :: :ok | no_return
  def async_increment(buffer, key, count \\ 1)

  def async_increment(buffer, key, count) when is_integer(count) do
    if WorkerRegistry.key_exists?(buffer, key) do
      GenServer.cast(via_tuple(buffer, key), {:increment, count})
    else
      new_worker(buffer, key, count)
    end
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
  @spec flush(buffer :: StatBuffer.t(), key :: any) :: :ok | no_return
  def flush(buffer, key) do
    GenServer.call(via_tuple(buffer, key), :flush)
  end

  @doc """
  Returns the current state of a buffers key.

  ## Parameters

    - buffer: A buffer module.
    - key: Any valid term.
  """
  @spec state(buffer :: StatBuffer.t(), key :: any) :: StatBuffer.State.t() | no_return
  def state(buffer, key) do
    GenServer.call(via_tuple(buffer, key), :state)
  end

  defp new_worker(buffer, key, count) do
    case WorkerSupervisor.start_worker(buffer, key, count) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> increment(buffer, key, count)
    end
  end

  defp via_tuple(%State{buffer: buffer, key: key}) do
    via_tuple(buffer, key)
  end

  defp via_tuple(buffer, key) do
    {:via, Registry, {StatBuffer.WorkerRegistry, {buffer, key}}}
  end
end
