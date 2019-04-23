defmodule StatBuffer.InitializerTest do
  use ExUnit.Case

  alias StatBuffer.Initializer

  defmodule TestBufferOne do
    use StatBuffer, interval: 1_000
  end

  defmodule TestBufferTwo do
    use StatBuffer, interval: 1_000
  end

  defmodule TestBufferThree do
    use StatBuffer, interval: 1_000
  end

  defmodule TestBufferFour do
    use StatBuffer, interval: 1_000
  end

  describe "start_link/1" do
    test "will start a list of buffers" do
      assert TestBufferOne.increment("foo") == :error
      assert TestBufferTwo.increment("foo") == :error
      assert :ignore = Initializer.start_link([TestBufferOne, TestBufferTwo])
      assert TestBufferOne.increment("foo") == :ok
      assert TestBufferTwo.increment("foo") == :ok
    end

    test "will start buffers form app config" do
      Application.put_env(:stat_buffer, :buffers, [TestBufferThree, TestBufferFour])

      assert TestBufferThree.increment("foo") == :error
      assert TestBufferFour.increment("foo") == :error
      assert :ignore = Initializer.start_link()
      assert TestBufferThree.increment("foo") == :ok
      assert TestBufferFour.increment("foo") == :ok

      Application.put_env(:stat_buffer, :buffers, [])
    end
  end
end
