defmodule StatBuffer.WorkerRegistry do
  @moduledoc false

  alias StatBuffer.State

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {Registry, :start_link, [[keys: :unique, name: __MODULE__]]}
    }
  end

  def key_exists?(buffer, key) do
    case Registry.lookup(__MODULE__, {buffer, key}) do
      [] -> false
      _ -> true
    end
  end

  def remove_key(%State{buffer: buffer, key: key}) do
    remove_key(buffer, key)
  end

  def remove_key(buffer, key) do
    Registry.unregister(__MODULE__, {buffer, key})
  end
end
