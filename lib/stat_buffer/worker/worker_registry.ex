defmodule StatBuffer.WorkerRegistry do
  @moduledoc false

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {Registry, :start_link, [[keys: :unique, name: __MODULE__]]}
    }
  end

  def exists?(buffer) do
    case Registry.lookup(__MODULE__, buffer) do
      [] -> false
      _ -> true
    end
  end

  def remove(buffer) do
    Registry.unregister(__MODULE__, buffer)
  end
end
