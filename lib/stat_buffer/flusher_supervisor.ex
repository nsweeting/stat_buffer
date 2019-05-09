defmodule StatBuffer.FlusherSupervisor do
  @moduledoc false

  use DynamicSupervisor

  ################################
  # Public API
  ################################

  @spec start_link(buffer :: StatBuffer.t()) :: Supervisor.on_start()
  def start_link(buffer) do
    DynamicSupervisor.start_link(__MODULE__, [], name: name(buffer))
  end

  @spec start_flusher(
          buffer :: StatBuffer.t(),
          key :: any(),
          count :: integer(),
          keyword()
        ) :: DynamicSupervisor.on_start_child()
  def start_flusher(buffer, key, count, opts \\ []) do
    buffer
    |> name()
    |> DynamicSupervisor.start_child({StatBuffer.Flusher, [buffer, key, count, opts]})
  end

  ################################
  # DynamicSupervisor Callbacks
  ################################

  @doc false
  @impl DynamicSupervisor
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  ################################
  # Private Functions
  ################################

  defp name(buffer) do
    Module.concat(buffer, FlusherSupervisor)
  end
end
