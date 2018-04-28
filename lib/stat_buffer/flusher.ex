defmodule StatBuffer.Flusher do
  @moduledoc false

  alias StatBuffer.State

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

    - state: A state struct.
  """
  @spec run(state :: StatBuffer.State.t()) :: :ok | no_return
  def run(%State{counter: 0}) do
    :ok
  end

  def run(%State{} = state) do
    case apply(state.buffer, :handle_flush, [state.key, state.counter]) do
      :ok ->
        :ok

      _ ->
        state.buffer.backoff() |> :timer.sleep()
        raise StatBuffer.Error, "buffer flush failed "
    end
  end

  @doc """
  Asynchronously flushes a buffers key.

  This will spawn a supervised Task that will retry based on the buffer modules
  task options.

  Please see `run/1` for further details.
  """
  def async_run(%State{} = state) do
    Task.Supervisor.start_child(__MODULE__, __MODULE__, :run, [state], state.buffer.task_opts())
  end
end
