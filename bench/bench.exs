defmodule BufferOne do
  use StatBuffer, interval: 60_000
end

defmodule BufferTwo do
  use StatBuffer, interval: 60_000
end

BufferOne.start_link()
BufferTwo.start_link()

# aync_increment/2 has recently been deprecated. There are now large performance
# gains in using increment/2.

Benchee.run(%{
  "increment" => fn -> BufferOne.increment(:foo) end,
  "async_increment" => fn -> BufferTwo.async_increment(:foo) end
})
