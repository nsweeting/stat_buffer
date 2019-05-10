defmodule BufferOne do
  use StatBuffer, interval: 60_000
end

defmodule BufferTwo do
  use StatBuffer, interval: 60_000
end

BufferOne.start_link()
BufferTwo.start_link()

Benchee.run(%{
  "increment" => fn -> BufferOne.increment(:foo) end,
  "async_increment" => fn -> BufferTwo.async_increment(:foo) end
})
