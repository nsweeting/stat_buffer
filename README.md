# StatBuffer

[![Build Status](https://travis-ci.org/nsweeting/stat_buffer.svg?branch=master)](https://travis-ci.org/nsweeting/stat_buffer)
[![StatBuffer Version](https://img.shields.io/hexpm/v/stat_buffer.svg)](https://hex.pm/packages/stat_buffer)

StatBuffer is an efficient way to maintain a local incrementable count with a given key. In fast moving systems,this provides a scalable way keep track of counts without putting heavy loads on a database.

## Installation

The package can be installed by adding `stat_buffer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:stat_buffer, "~> 0.1.0"}
  ]
end
```

## Documentation

Please see [HexDocs](https://hexdocs.pm/stat_buffer) for additional documentation.
This readme provides a brief overview, but it is recommended that the docs are
used.

## Creating a buffer module

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

With our buffer module defined, we can now increment key counters. A key can be any valid term.

```elixir
Buffer.increment("mykey") # increments by 1

Buffer.increment("mykey", 10) # increments by 10
```

And we're done! Our counter will be flushed using our `handle_flush/2` callback
after the default time period. Dead counters are automatically removed.

For further details on how all this works, as well as configurable options, please
check out the [docs](https://hexdocs.pm/stat_buffer).