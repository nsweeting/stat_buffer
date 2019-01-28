# StatBuffer

[![Build Status](https://travis-ci.org/nsweeting/stat_buffer.svg?branch=master)](https://travis-ci.org/nsweeting/stat_buffer)
[![StatBuffer Version](https://img.shields.io/hexpm/v/stat_buffer.svg)](https://hex.pm/packages/stat_buffer)

StatBuffer is an efficient way to maintain a local incrementable count with a given key that can later be flushed to persistent storage. In fast moving systems, this provides a scalable way keep track of counts without putting heavy loads on a database.

## Installation

The package can be installed by adding `stat_buffer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:stat_buffer, "~> 0.2.0"}
  ]
end
```

## Documentation

Please see [HexDocs](https://hexdocs.pm/stat_buffer/StatBuffer.html#content) for additional documentation. This readme provides a brief overview, but it is recommended that the docs are used.

## Creating a buffer

We can start off by creating our buffer. This is simply a module that uses `StatBuffer`
and implements the `handle_flush/2` callback.

```elixir
defmodule Buffer do
  use StatBuffer

  def handle_flush(key, counter) do
    # do database stuff...

    # we must return an :ok atom
    :ok
  end
end
```

We must now start our buffer process.

```elixir
  Buffer.start()
```

There are some configruable options available for our buffers. You can read more about them [here](https://hexdocs.pm/stat_buffer/StatBuffer.html#module-options). These options can be passed when creating our buffer.

```elixir
  use StatBuffer, interval: 10_000
```

With our buffer started, we can now increment key counters. A key can be any valid term.

```elixir
Buffer.increment("mykey") # increments by 1

Buffer.increment("mykey", 10) # increments by 10

Buffer.async_increment("mykey") # async increments by 1
```

And we're done! Our counter will be flushed using our `handle_flush/2` callback
after the default interval period. Dead counters are automatically removed.
