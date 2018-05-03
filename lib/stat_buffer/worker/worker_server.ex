defmodule StatBuffer.WorkerServer do
  @moduledoc false

  use GenServer

  alias StatBuffer.WorkerRegistry
  alias StatBuffer.Flusher

  def init(buffer) do
    do_table_init(buffer)
    {:ok, buffer, buffer.timeout()}
  end

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

  def handle_cast({:increment, key, count}, buffer) do
    do_increment(buffer, key, count)
    {:noreply, buffer, buffer.timeout()}
  end

  def handle_info({:flush, key}, buffer) do
    do_flush(buffer, key)
    {:noreply, buffer, buffer.timeout()}
  end

  def handle_info(:timeout, buffer) do
    {:noreply, buffer, :hibernate}
  end

  defp do_increment(buffer, key, count) do
    if :ets.update_counter(buffer, key, count, {0, 0}) == count do
      Process.send_after(self(), {:flush, key}, buffer.interval())
    end
  end

  defp do_lookup(buffer, key) do
    case :ets.lookup(buffer, key) do
      [{^key, count}] -> count
      _ -> nil
    end
  end

  defp do_flush(buffer, key) do
    case do_lookup(buffer, key) do
      nil -> :error
      count -> 
        :ets.delete(buffer, key)
        Flusher.async_run(buffer, key, count)
    end
  end

  def do_table_init(buffer) do
    case :ets.info(buffer) do
      :undefined -> :ets.new(buffer, [:public, :named_table])
      _ -> buffer
    end
  end
end
