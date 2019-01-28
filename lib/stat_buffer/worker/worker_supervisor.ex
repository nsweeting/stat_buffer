defmodule StatBuffer.WorkerSupervisor do
  @moduledoc false

  use DynamicSupervisor

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_worker(buffer :: StatBuffer.t()) :: GenServer.on_start()
  def start_worker(buffer) do
    DynamicSupervisor.start_child(__MODULE__, {StatBuffer.Worker, buffer})
  end

  @spec reset() :: non_neg_integer()
  def reset do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> GenServer.stop(pid, :normal) end)
    |> Enum.count(fn val -> val == :ok end)
  end

  @spec worker_count() :: non_neg_integer()
  def worker_count do
    %{workers: workers} = DynamicSupervisor.count_children(__MODULE__)
    workers
  end
end
