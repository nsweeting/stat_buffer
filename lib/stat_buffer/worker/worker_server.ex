defmodule StatBuffer.WorkerServer do
  @moduledoc false

  use GenServer

  alias StatBuffer.WorkerRegistry
  alias StatBuffer.Flusher
  alias StatBuffer.State

  def init(state) do
    schedule_flush(state)
    {:ok, {state, true}, state.buffer.timeout()}
  end

  def handle_call(:state, _from, {state, scheduled}) do
    {:reply, state, {state, scheduled}, state.buffer.timeout()}
  end

  def handle_call(:flush, _from, {state, scheduled}) do
    Flusher.async_run(state)
    state = State.reset(state)
    {:reply, :ok, {state, scheduled}, state.buffer.timeout()}
  end

  def handle_call({:increment, count}, _from, {state, false}) do
    schedule_flush(state)
    state = State.increment(state, count)
    {:reply, :ok, {state, true}, state.buffer.timeout()}
  end

  def handle_call({:increment, count}, _from, {state, true}) do
    state = State.increment(state, count)
    {:reply, :ok, {state, true}, state.buffer.timeout()}
  end

  def handle_cast({:increment, count}, {state, false}) do
    schedule_flush(state)
    state = State.increment(state, count)
    {:noreply, {state, true}, state.buffer.timeout()}
  end

  def handle_cast({:increment, count}, {state, true}) do
    state = State.increment(state, count)
    {:noreply, {state, true}, state.buffer.timeout()}
  end

  def handle_info(:flush, {state, _scheduled}) do
    Flusher.async_run(state)
    state = State.reset(state)
    {:noreply, {state, false}, state.buffer.timeout()}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def terminate(_reason, {state, _scheduled}) do
    Flusher.async_run(state)
    WorkerRegistry.remove_key(state)
    state
  end

  defp schedule_flush(state) do
    Process.send_after(self(), :flush, state.buffer.interval())
  end
end
