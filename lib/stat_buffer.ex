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

  Once we have defined our buffer module, all we must do is implement a
  `handle_flush/2` callback that allows us to perform an operation with a
  provided key and counter. This typically means updating a counter in a
  database.

      defmodule Buffer do
        use StatBuffer

        def handle_flush(key, counter) do
          # write to the database...

          # handle_flush MUST return an :ok atom
          :ok
        end
      end

  Each flush operation is handled with its own supervised `Task` process. By
  default, a failed flush operation will retry about 3 times within 3 seconds.

  ## Usage

  Before using our buffer, we must start it.

      Buffer.start()

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

    * `:restart` - the `:restart` option used for the flush task. Please see
    `Task.Supervisor.start_child/2` for more details.

    * `:shutdown` - the `:shutdown` option used for the flush task. Please see
    `Task.Supervisor.start_child/2` for more details.
  """

  @doc """
  Starts the buffer process. 
  """
  @callback start :: GenServer.on_start()

  @doc """
  Callback for flushing a key for the buffer.

  When a buffer key hits its set time interval, this function will be called and
  provided with the key as well its current counter.

  This function is called within its own Task and is supervised. If the
  callback does not return `:ok` - the task will fail and attempt a retry
  with configurable backoff.

  ## Parameters

    - key: Any valid term.
    - counter: An integer counter.
  """
  @callback handle_flush(key :: any, counter :: integer) :: :ok

  @doc """
  Increments a given key in the buffer by the provided count.

  Each key is scoped to the buffer module. So duplicate keys across different
  buffer modules will not cause issues.

  ## Parameters

    - key: Any valid term.
    - count: An integer count. Defaults to 1.
  """
  @callback increment(key :: any, count :: integer) :: :ok

  @doc """
  Same as `increment/2` except performs the operation asynchronously.
  """
  @callback async_increment(key :: any, count :: integer) :: :ok

  @doc """
  Asynchronously flushes a given key from the buffer.
  """
  @callback flush(key :: any) :: :ok | no_return()

  @doc """
  Returns the current state of a key from the buffer.
  """
  @callback count(key :: any) :: integer | nil | no_return()

  @doc """
  The amount of time between buffer flush operations. If specified in the
  options, a jitter may be applied.
  """
  @callback interval :: integer

  @doc """
  The amount of time that a buffer key process will remain without recieving
  work before shutting down.
  """
  @callback timeout :: integer

  @doc """
  The amount of time that will be applied between failed key flush attempts.
  """
  @callback backoff :: integer

  @doc """
  The options that will be used when a supervised Task is started to flush
  the buffer.
  """
  @callback task_opts :: list

  @type t :: module

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour StatBuffer

      defaults = [
        interval: 5_000,
        jitter: 0,
        timeout: 10_000,
        backoff: 1_000,
        restart: :transient,
        shutdown: :brutal_kill
      ]

      @opts Keyword.merge(defaults, opts)

      def start do
        StatBuffer.WorkerSupervisor.start_worker(__MODULE__)
      end

      def handle_flush(_key, _counter) do
        :ok
      end

      def increment(key, count \\ 1) do
        StatBuffer.Worker.increment(__MODULE__, key, count)
      end

      def async_increment(key, count \\ 1) do
        StatBuffer.Worker.async_increment(__MODULE__, key, count)
      end

      def flush(key) do
        StatBuffer.Worker.flush(__MODULE__, key)
      end

      def count(key) do
        StatBuffer.Worker.count(__MODULE__, key)
      end

      def interval do
        if @opts[:jitter] > 0 do
          @opts[:interval] + :rand.uniform(@opts[:jitter])
        else
          @opts[:interval]
        end
      end

      def timeout do
        @opts[:timeout]
      end

      def backoff do
        @opts[:backoff]
      end

      def task_opts do
        [restart: @opts[:restart], shutdown: @opts[:shutdown]]
      end

      defoverridable StatBuffer
    end
  end
end
