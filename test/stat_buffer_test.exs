defmodule StatBufferTest do
  use ExUnit.Case

  defmodule TestBufferOne do
    use StatBuffer, interval: 1_000
  end

  defmodule TestBufferTwo do
    use StatBuffer, interval: 1_000
  end

  defmodule TestBufferThree do
    use StatBuffer, interval: 100

    def handle_flush(key, count) do
      send(:stat_buffer_test, {key, count})
    end
  end

  defmodule TestBufferFour do
    use StatBuffer, timeout: 100
  end

  setup do
    StatBuffer.WorkerSupervisor.reset()
    :ok
  end

  describe "increment/2" do
    test "accepts a binary as a key" do
      TestBufferOne.start()
      TestBufferOne.increment("foo", 1)
      assert_key_exists(TestBufferOne, "foo")
    end

    test "accepts a tuple as a key" do
      TestBufferOne.start()
      TestBufferOne.increment({"foo", "bar"}, 1)
      assert_key_exists(TestBufferOne, {"foo", "bar"})
    end

    test "accepts an integer as a key" do
      TestBufferOne.start()
      TestBufferOne.increment(1, 1)
      assert_key_exists(TestBufferOne, 1)
    end

    test "accepts an atom as a key" do
      TestBufferOne.start()
      TestBufferOne.increment(:foo, 1)
      assert_key_exists(TestBufferOne, :foo)
    end

    test "initializes a stat key with a proper count" do
      TestBufferOne.start()
      TestBufferOne.increment("foo", 10)
      assert_key_count(TestBufferOne, "foo", 10)
    end

    test "maintains a proper stat count for a single key" do
      TestBufferOne.start()
      TestBufferOne.increment("foo", 1)
      TestBufferOne.increment("foo", 1)
      TestBufferOne.increment("foo", 1)
      assert_key_count(TestBufferOne, "foo", 3)
    end

    test "maintains a proper stat count for a single key with concurrency" do
      TestBufferOne.start()
  
      for _ <- 1..10_000 do
        spawn(fn -> TestBufferOne.async_increment("foo", 1) end)
      end

      await_count(TestBufferOne, "foo", 10_000)
      assert_key_count(TestBufferOne, "foo", 10_000)
    end

    test "does not mix keys from different buffers" do
      TestBufferOne.start()
      TestBufferTwo.start()

      TestBufferOne.increment("foo", 100)
      assert_key_count(TestBufferOne, "foo", 100)

      TestBufferTwo.increment("foo", 10)
      assert_key_count(TestBufferTwo, "foo", 10)
    end

    test "will cause a flush after the specified interval" do
      TestBufferThree.start()
      Process.register(self(), :stat_buffer_test)
      TestBufferThree.increment("foo", 1)
      TestBufferThree.increment("foo", 1)
      :timer.sleep(200)
      assert_receive({"foo", 2})
    end

    test "will cause the worker to hibernate after the specified timeout" do
      {:ok, pid} = TestBufferFour.start()
      TestBufferFour.increment("foo", 1)
      :timer.sleep(200)
      info = Process.info(pid)
      assert info[:current_function] == {:erlang, :hibernate, 3}
    end
  end

  def assert_key_exists(buffer, key) do
    assert buffer |> StatBuffer.Worker.count(key) |> is_integer()
  end

  def refute_key_exists(buffer, key) do
    assert buffer |> StatBuffer.Worker.count(key) |> is_nil()
  end

  def assert_key_count(buffer, key, count) do
    assert StatBuffer.Worker.count(buffer, key) == count
  end

  def assert_worker_count(count) do
    StatBuffer.WorkerSupervisor.worker_count() == count
  end

  def await_count(buffer, key, count) do
    :timer.sleep(10)

    case StatBuffer.Worker.count(buffer, key) do
      ^count -> :ok
      _ -> await_count(buffer, key, count)
    end
  end
end
