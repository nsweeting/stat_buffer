defmodule StatBuffer.Flusher do
  @moduledoc false

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {Task.Supervisor, :start_link, [[name: __MODULE__]]}
    }
  end

  @doc """
  Flushes a buffers key.

  If the given key has a counter of 0 - this becomes a noop. Otherwise, the
  states buffer modules `handle_flush/2` callback will be called.

  ## Parameters

    - buffer: A state struct.
  """
  @spec run(buffer :: StatBuffer.t(), key :: any(), count :: integer()) :: :ok | no_return
  def run(_buffer, _key, 0) do
    :ok
  end

  def run(buffer, key, count) do
    case apply(buffer, :handle_flush, [key, count]) do
      :ok ->
        :ok

      _ ->
        buffer.backoff() |> :timer.sleep()
        raise StatBuffer.Error, "buffer flush failed "
    end
  end

  @doc """
  Asynchronously flushes a buffers key.

  This will spawn a supervised Task that will retry based on the buffer modules
  task options.

  Please see `run/1` for further details.
  """
  def async_run(buffer, key, count) do
    Task.Supervisor.start_child(__MODULE__, __MODULE__, :run, [buffer, key, count], buffer.task_opts())
  end

  def reset do
    for pid <- Task.Supervisor.children(__MODULE__) do
      Task.Supervisor.terminate_child(__MODULE__, pid)
    end
  end
end
