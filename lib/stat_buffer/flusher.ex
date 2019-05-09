defmodule StatBuffer.Flusher do
  @moduledoc false

  @type option :: {:backoff, non_neg_integer()}
  @type options :: [option()]

  ################################
  # Public API
  ################################

  @spec start_link(buffer :: StatBuffer.t(), key :: any(), count :: integer(), options()) ::
          {:ok, pid()}
  def start_link(buffer, key, count, opts \\ []) do
    Task.start_link(__MODULE__, :run, [buffer, key, count, opts])
  end

  @doc false
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, args},
      restart: :transient
    }
  end

  @spec run(buffer :: StatBuffer.t(), key :: any(), count :: integer(), backoff :: integer()) ::
          :ok | no_return
  def run(_buffer, _key, 0, _opts) do
    :ok
  end

  def run(buffer, key, count, opts) do
    case apply(buffer, :handle_flush, [key, count]) do
      :ok ->
        :ok

      _ ->
        :timer.sleep(opts[:backoff] || 0)
        raise StatBuffer.Error, "buffer flush failed "
    end
  end
end
