# Attempt

Implements a retry budget to support a rate-limited and retry capable function
execution.

This is particularly helpful in two broad cases both of which involve
transient errors

* Accessing external services which may require rate limiting by clients and which also may suffer from transient errors (network or performance issues for example)

* Invoking local services like a database that may return errors which, if executed again, would likely not re-occur.  For example, executing a database update which cannot be completed because of resource contention could be safely retried.

## Usage

See primarily:

* `Attempt.execute/2` which is the main public api
* `Attempt.Bucket.Token.new/2` which defines how to create a token bucket
* `Attempt.Retry.DefaultPolicy` which shows how a retry policy is defined
* `Attempt.Retry.Exception` which shows how to classify an exception return

```
  iex#> Attempt.execute fn -> "Hello World" end
  "Hello World"

  iex#> Attempt.execute fn -> IO.puts "Reraise Failure!"; div(1,0) end, tries: 3
  Reraise Failure!
  ** (ArithmeticError) bad argument in arithmetic expression
      :erlang.div(1, 0)
      (attempt) lib/attempt.ex:119: Attempt.execute_function/1
      (attempt) lib/attempt.ex:98: Attempt.execute/6

  iex#> Attempt.execute fn -> IO.puts "Try 3 times"; :error end, tries: 3
  Try 3 times
  Try 3 times
  Try 3 times
  :error

  # Create a bucket that adds a new token only every 10 seconds
  iex#> {:ok, bucket} = Attempt.Bucket.Token.new :test, fill_rate: 10_000

  iex#> Attempt.execute fn ->
          IO.puts "Try 11 times and we'll timeout claiming a token"
          :error
        end, tries: 11, token_bucket: bucket
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  Try 11 times and we'll timeout claiming a token
  {:error, {:timeout, {GenServer, :call, [:test, :claim_token, 5000]}}}
```

## Topics for discussion

* The `Token Bucket` implementation creates a `GenServer` for each bucket and uses `Process.send_after/3` to add tokens to the bucket.  Is this the best approach?

* Part of the reason for using a timer-based approach to adding tokens is that it greatly simplifies token acquisition from a client application perspective.  `Attempt.Bucket.claim_token/2` will only return when it has a token or there is a timeout on the acquisition.  Requests are added to a queue when no tokens are available and the queue is processed every time a new token is added and a new claim request is received.  Its possible a selective receive strategy would be better.

* The api may be cleaner if a `block form` could be defined.  That would require a macro but it would mean we could have:

```
    Attempt.execute fill_rate: 1_000, burst_size: 100 do
      # execute some function
    end
```

* Currently when an exception is returned from the function but the retry policy defines it to be a `:return` classification (rather than a `:reraise` classification) the return is a tuple `{exception, stacktrace}`.  Its not clear thats the most meaninful return result.

## Todo

* [ ] Enforce maximum queue depth in `Attempt.Bucket.Token`
* [ ] Implement a [Leaky Bucket](https://en.wikipedia.org/wiki/Leaky_bucket)
* [ ] Wire up retry backoff strategies into `Attempt.execute/2`
* [ ] Tests
* [ ] Specs
* [ ] Improve Documentation
* [ ] Implement the `!` version of `Attempt.execute!/2`

## Installation

`Attempt` can be installed by adding `attempt` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:attempt, "~> 0.2.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/attempt](https://hexdocs.pm/attempt).

