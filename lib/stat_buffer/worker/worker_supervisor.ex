defmodule StatBuffer.WorkerSupervisor do
  @moduledoc false

  use DynamicSupervisor

  alias StatBuffer.State
  alias StatBuffer.Worker

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_worker(buffer) do
    DynamicSupervisor.start_child(__MODULE__, {Worker, buffer})
  end

  def reset do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> GenServer.stop(pid, :normal) end)
    |> Enum.count(fn val -> val == :ok end)
  end

  def worker_count do
    %{workers: workers} = DynamicSupervisor.count_children(__MODULE__)
    workers
  end
end
