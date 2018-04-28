defmodule StatBuffer.State do
  @moduledoc false

  defstruct [
    :buffer,
    :key,
    :counter
  ]

  alias StatBuffer.State

  @type t :: %__MODULE__{
    buffer: StatBuffer.t(),
    key: any,
    counter: integer
  }

  @doc """
  Creates a new state struct.

  ## Parameters

  - buffer: A buffer module.
  - key: Any valid term.
  - counter: A starting count.
  """
  @spec new(buffer :: StatBuffer.t(), key :: any, counter :: integer) :: t
  def new(buffer, key, counter) do
    %State{}
    |> put_buffer(buffer)
    |> put_key(key)
    |> put_counter(counter)
  end

  @doc """
  Puts a buffer module in a state struct.

  ## Parameters

  - state: A state struct.
  - buffer: A buffer module.
  """
  @spec put_buffer(state :: t, buffer :: StatBuffer.t()) :: t
  def put_buffer(state, buffer) do
    %{state | buffer: buffer}
  end

  @doc """
  Puts a key in a state struct.

  ## Parameters

  - state: A state struct.
  - key: Any valid key.
  """
  @spec put_key(state :: t, key :: any) :: t
  def put_key(state, key) do
    %{state | key: key}
  end

  @doc """
  Puts a counter in a state struct.

  ## Parameters

  - state: A state struct.
  - counter: Any integer.
  """
  @spec put_counter(state :: t, counter :: integer) :: t
  def put_counter(state, counter) when is_integer(counter) do
    %{state | counter: counter}
  end

  def put_counter(_state, _counter) do
    raise ArgumentError, "counter must be an integer"
  end

  @doc """
  Increments a state structs counter by the given count.

  ## Parameters

  - state: A state struct.
  - count: Any integer.
  """
  @spec increment(state :: t, count :: integer) :: t
  def increment(state, count) when is_integer(count) do
    %{state | counter: state.counter + count}
  end

  def increment(_state, _count) do
    raise ArgumentError, "count must be an integer"
  end

  @doc """
  Resets a state structs counter to 0.

  ## Parameters

  - state: A state struct.
  """
  @spec reset(state :: t) :: t
  def reset(state) do
    %{state | counter: 0}
  end
end
