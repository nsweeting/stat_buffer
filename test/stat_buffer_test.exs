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
      TestBufferOne.increment("foo", 1)
      assert_key_exists(TestBufferOne, "foo")
    end

    test "accepts a tuple as a key" do
      TestBufferOne.increment({"foo", "bar"}, 1)
      assert_key_exists(TestBufferOne, {"foo", "bar"})
    end

    test "accepts an integer as a key" do
      TestBufferOne.increment(1, 1)
      assert_key_exists(TestBufferOne, 1)
    end

    test "accepts an atom as a key" do
      TestBufferOne.increment(:foo, 1)
      assert_key_exists(TestBufferOne, :foo)
    end

    test "creates a stat worker if the key doesnt exist" do
      assert_worker_count(0)
      TestBufferOne.increment("foo", 1)
      assert_worker_count(1)
    end

    test "reuses the stat worker if the key already exists" do
      assert_worker_count(0)
      TestBufferOne.increment("foo", 1)
      assert_worker_count(1)
      TestBufferOne.increment("foo", 1)
      assert_worker_count(1)
    end

    test "creates new stat workers for each new key" do
      assert_worker_count(0)
      TestBufferOne.increment("foo1", 1)
      assert_worker_count(1)
      TestBufferOne.increment("foo2", 1)
      assert_worker_count(2)
      TestBufferOne.increment("foo3", 1)
      assert_worker_count(3)
    end

    test "maintains a proper stat count for a single key" do
      TestBufferOne.increment("foo", 1)
      TestBufferOne.increment("foo", 1)
      TestBufferOne.increment("foo", 1)
      assert_worker_counter(TestBufferOne, "foo", 3)
    end

    test "maintains a proper stat count for a single key with concurrency" do
      for _ <- 1..10_000 do
        spawn(fn -> TestBufferOne.async_increment("foo", 1) end)
      end

      await_counter(TestBufferOne, "foo", 10_000)
      assert_worker_counter(TestBufferOne, "foo", 10_000)
    end

    test "does not mix keys from different buffers" do
      assert_worker_count(0)
      TestBufferOne.increment("foo", 1)
      assert_worker_count(1)
      assert_key_exists(TestBufferOne, "foo")
      TestBufferTwo.increment("foo", 1)
      assert_worker_count(2)
      assert_key_exists(TestBufferTwo, "foo")
    end

    test "will cause a flush after the specified interval" do
      Process.register(self(), :stat_buffer_test)
      TestBufferThree.increment("foo", 1)
      TestBufferThree.increment("foo", 1)
      :timer.sleep(200)
      assert_receive({"foo", 2})
    end

    test "will cause the worker to exit after the specified timeout" do
      TestBufferFour.increment("foo", 1)
      assert_worker_count(1)
      :timer.sleep(200)
      assert_worker_count(0)
    end
  end

  def assert_key_exists(buffer, key) do
    assert StatBuffer.WorkerRegistry.key_exists?(buffer, key)
  end

  def assert_worker_count(count) do
    StatBuffer.WorkerSupervisor.worker_count() == count
  end

  def assert_worker_counter(buffer, key, counter) do
    %{counter: current_counter} = StatBuffer.Worker.state(buffer, key)
    assert current_counter == counter
  end

  def await_counter(buffer, key, counter) do
    :timer.sleep(10)

    case StatBuffer.Worker.state(buffer, key) do
      %{counter: ^counter} -> :ok
      _ -> await_counter(buffer, key, counter)
    end
  end
end
