defmodule StatBuffer.Initializer do
  @moduledoc false

  use GenServer

  ################################
  # Public API
  ################################

  @doc false
  def child_spec(buffers) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [buffers]}
    }
  end

  @doc """
  Starts the buffer initialization process.
  """
  @spec start_link(buffers :: [StatBuffer.t()]) :: :ignore | {:error, any()}
  def start_link(buffers \\ []) do
    GenServer.start_link(__MODULE__, buffers)
  end

  ################################
  # GenServer Callbacks
  ################################

  @doc false
  @impl GenServer
  def init(buffers) do
    app_buffers = Application.get_env(:stat_buffer, :buffers, [])
    buffers = buffers ++ app_buffers
    do_start_buffers(buffers)
  end

  ################################
  # Private Functions
  ################################

  defp do_start_buffers([]) do
    :ignore
  end

  defp do_start_buffers([buffer | buffers]) do
    case apply(buffer, :start, []) do
      {:ok, _pid} -> do_start_buffers(buffers)
      other -> other
    end
  end
end
