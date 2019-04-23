defmodule StatBuffer.Application do
  @moduledoc false

  use Application

  ################################
  # Application Callbacks
  ################################

  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    children = [
      StatBuffer.WorkerSupervisor,
      StatBuffer.Flusher,
      StatBuffer.Initializer
    ]

    opts = [strategy: :rest_for_one, name: StatBuffer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
