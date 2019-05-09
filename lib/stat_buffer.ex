defmodule StatBuffer do
  @moduledoc """
  Defines a stat buffer.

  A stat buffer is an efficient way to maintain a local incrementable count with a
  given key that can later be flushed to persistent storage. In fast moving systems,
  this provides a scalable way keep track of counts without putting heavy loads
  on a database.

  Creating a buffer is as easy as:

      defmodule Buffer do
        use StatBuffer
      end

  Once we have defined our buffer module, we must then implement the `handle_flush/2`
  callback that allows us to perform an operation with a rovided key and counter.
  This could mean something like updating a counter in a database.

      defmodule Buffer do
        use StatBuffer

        def handle_flush(key, counter) do
          # write to the database...

          # handle_flush MUST return an :ok atom
          :ok
        end
      end

  We must then add our buffer to our supervision tree.

      children = [
        Buffer
      ]

  Each flush operation is handled with its own supervised `Task` process. By
  default, a failed flush operation will retry about 3 times within 3 seconds.

  ## Usage

  With our buffer started, we can now increment key counters. A key can be any
  valid term.

      Buffer.increment("mykey") # increments by 1

      Buffer.increment("mykey", 10) # increments by 10

      Buffer.async_increment("mykey") # async increments by 1

  Key counts are maintained in an ETS table. All keys are scoped to the given
  buffer module - so multiple buffers using the same keys will not cause issues.

  With the default buffer we setup above, the "mykey" counter will be flushed
  after 5 seconds. Assuming no new operations occur with our buffer, the process
  will be placed into hibernation after 10 seconds. All of this is configurable
  through the options below.

  ## Options

  A stat buffer comes with a few configurable options. We can pass any of these
  options along with the use macro.

      use StatBuffer, interval: 60_000, jitter: 20_000

    * `:interval` - the time in milliseconds between the first increment for a
    given key and its next flush callback being invoked. Defaults to `5_000`.

    * `:jitter` - a max time in milliseconds that will be added to `interval` to
    ensure some randomness in each flush invocation. The time added would be
    randomly selected between 0 and `jitter`. Defaults to `0`.

    * `:timeout` - the time in milliseconds between the last operation on a
    a buffer, and the process being hibernated. Defaults to `10_000`.

    * `:backoff` - the time in milliseconds between a `handle_flush/2` callback
    failing, and the next attempt occuring. Defaults to `1_000`.
  """

  @doc """
  Starts the buffer process.

  ## Options

  The options available are the same provided in the "Options" section.
  """
  @callback start_link(options()) :: GenServer.on_start()

  @doc """
  Callback for flushing a key for the buffer.

  When a buffer key hits its set time interval, this function will be called and
  provided with the key as well its current counter.

  This function is called within its own Task and is supervised. If the
  callback does not return `:ok` - the task will fail and attempt a retry
  with configurable backoff.
  """
  @callback handle_flush(key :: any(), counter :: integer()) :: :ok

  @doc """
  Increments a given key in the buffer by the provided count.

  Each key is scoped to the buffer module. So duplicate keys across different
  buffer modules will not cause issues.
  """
  @callback increment(key :: any(), count :: integer()) :: :ok | :error

  @doc """
  Same as `increment/2` except performs the operation asynchronously.
  """
  @callback async_increment(key :: any(), count :: integer()) :: :ok

  @doc """
  Asynchronously flushes a given key from the buffer.
  """
  @callback flush(key :: any()) :: :ok

  @doc """
  Returns the current state of a key from the buffer.
  """
  @callback count(key :: any()) :: integer() | nil

  @type t :: module
  @type option ::
          {:interval, non_neg_integer()}
          | {:jitter, non_neg_integer()}
          | {:timeout, non_neg_integer()}
          | {:backoff, non_neg_integer()}
  @type options :: [option()]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour StatBuffer

      default_opts = [
        interval: 5_000,
        jitter: 0,
        timeout: 10_000,
        backoff: 1_000
      ]

      @opts Keyword.merge(default_opts, opts)

      @impl StatBuffer
      def start_link(opts \\ []) do
        opts = Keyword.merge(@opts, opts)
        StatBuffer.Supervisor.start_link(__MODULE__, opts)
      end

      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      @impl StatBuffer
      def handle_flush(_key, _counter) do
        :ok
      end

      @impl StatBuffer
      def increment(key, count \\ 1) do
        StatBuffer.Worker.increment(__MODULE__, key, count)
      end

      @impl StatBuffer
      def async_increment(key, count \\ 1) do
        StatBuffer.Worker.async_increment(__MODULE__, key, count)
      end

      @impl StatBuffer
      def flush(key) do
        StatBuffer.Worker.flush(__MODULE__, key)
      end

      @impl StatBuffer
      def count(key) do
        StatBuffer.Worker.count(__MODULE__, key)
      end

      defoverridable handle_flush: 2
    end
  end
end
