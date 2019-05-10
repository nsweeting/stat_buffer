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

  defmodule TestBufferFive do
    use StatBuffer, timeout: 100
  end

  defmodule TestBufferSix do
    use StatBuffer, interval: 0

    def handle_flush(key, count) do
      send(:stat_buffer_test, {key, count})
      raise "error"
    end
  end

  defmodule TestBufferSeven do
    use StatBuffer, interval: 0, backoff: 200

    def handle_flush(key, _count) do
      send(:stat_buffer_test, {key, :os.system_time(:millisecond)})
      :error
    end
  end

  describe "increment/2" do
    test "accepts a binary as a key" do
      start_supervised(TestBufferOne)
      TestBufferOne.increment("foo", 1)
      assert_key_exists(TestBufferOne, "foo")
    end

    test "accepts a tuple as a key" do
      start_supervised(TestBufferOne)
      TestBufferOne.increment({"foo", "bar"}, 1)
      assert_key_exists(TestBufferOne, {"foo", "bar"})
    end

    test "accepts an integer as a key" do
      start_supervised(TestBufferOne)
      TestBufferOne.increment(1, 1)
      assert_key_exists(TestBufferOne, 1)
    end

    test "accepts an atom as a key" do
      start_supervised(TestBufferOne)
      TestBufferOne.increment(:foo, 1)
      assert_key_exists(TestBufferOne, :foo)
    end

    test "initializes a stat key with a proper count" do
      start_supervised(TestBufferOne)
      TestBufferOne.increment("foo", 10)
      assert_key_count(TestBufferOne, "foo", 10)
    end

    test "maintains a proper stat count for a single key" do
      start_supervised(TestBufferOne)
      TestBufferOne.increment("foo", 1)
      TestBufferOne.increment("foo", 1)
      TestBufferOne.increment("foo", 1)
      assert_key_count(TestBufferOne, "foo", 3)
    end

    test "maintains a proper stat count for a single key with concurrency" do
      start_supervised(TestBufferOne)

      for _ <- 1..10_000 do
        spawn(fn -> TestBufferOne.async_increment("foo", 1) end)
      end

      await_count(TestBufferOne, "foo", 10_000)
      assert_key_count(TestBufferOne, "foo", 10_000)
    end

    test "does not mix keys from different buffers" do
      start_supervised(TestBufferOne)
      start_supervised(TestBufferTwo)

      TestBufferOne.increment("foo", 100)
      assert_key_count(TestBufferOne, "foo", 100)

      TestBufferTwo.increment("foo", 10)
      assert_key_count(TestBufferTwo, "foo", 10)
    end

    test "will cause a flush after the specified interval" do
      start_supervised(TestBufferThree)
      Process.register(self(), :stat_buffer_test)
      TestBufferThree.increment("foo", 1)
      TestBufferThree.increment("foo", 1)
      :timer.sleep(200)
      assert_receive({"foo", 2})
    end

    test "will cause the worker to hibernate after the specified timeout" do
      start_supervised(TestBufferFour)
      TestBufferFour.increment("foo", 1)
      :timer.sleep(200)
      pid = Process.whereis(TestBufferFour)
      info = Process.info(pid)
      assert info[:current_function] == {:erlang, :hibernate, 3}
    end

    @tag capture_log: true
    test "will return :error if the process isnt alive" do
      assert :error = TestBufferFive.increment("foo")
    end

    @tag capture_log: true
    test "will retry failed flush operations" do
      start_supervised(TestBufferSix)
      Process.register(self(), :stat_buffer_test)
      TestBufferSix.increment("foo")

      :timer.sleep(100)

      assert_receive({"foo", 1})
      assert_receive({"foo", 1})
      assert_receive({"foo", 1})
      assert_receive({"foo", 1})
    end

    @tag capture_log: true
    test "will retry with backoff flush operations that dont return :ok " do
      start_supervised(TestBufferSeven)
      Process.register(self(), :stat_buffer_test)
      TestBufferSeven.increment("foo")

      :timer.sleep(100)

      assert_receive({"foo", time1}, 500)
      assert_receive({"foo", time2}, 500)
      assert time2 - time1 > 200
      assert_receive({"foo", time1}, 500)
      assert_receive({"foo", time2}, 500)
      assert time2 - time1 > 200
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

  def await_count(buffer, key, count) do
    :timer.sleep(10)

    case StatBuffer.Worker.count(buffer, key) do
      ^count -> :ok
      _ -> await_count(buffer, key, count)
    end
  end
end
