# Attempt

Implements a retry budget to support a rate-limited and retry capable function
execution.

This is particularly helpful in two broad cases both of which involve
transient errors

* Accessing external services which may require rate limiting by clients and which also may suffer from transient errors (network or performance issues for example)

* Invoking local services like a database that may return errors which, if executed again, would likely not re-occur.  For example, executing a database update which cannot be completed because of resource contention could be safely retried.

## Usage

See primarily:

* `Attempt.run/2` which is the main public api
* `Attempt.Bucket.Token.new/2` which defines how to create a token bucket
* `Attempt.Retry.Policy.Default` which shows how a retry policy is defined
* `Attempt.Retry.Backoff.None` which shows the default backoff strategy
* `Attempt.Retry.Exception` which shows how to classify an exception return

```
  iex#> Attempt.run fn -> "Hello World" end
  "Hello World"

  iex#> Attempt.run fn -> IO.puts "Reraise Failure!"; div(1,0) end, tries: 3
  Reraise Failure!
  ** (ArithmeticError) bad argument in arithmetic expression
      :erlang.div(1, 0)
      (attempt) lib/attempt.ex:119: Attempt.execute_function/1
      (attempt) lib/attempt.ex:98: Attempt.execute/6

  iex#> Attempt.run fn -> IO.puts "Try 3 times"; :error end, tries: 3
  Try 3 times
  Try 3 times
  Try 3 times
  :error

  # Create a bucket that adds a new token only every 10 seconds
  iex#> {:ok, bucket} = Attempt.Bucket.Token.new :test, fill_rate: 10_000

  iex#> Attempt.run fn ->
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
### Block form

`Attempt.execute/1/2` is now a macro that allows a block form of coding. On delegates to `Attempt.run/2` after argument processing.

```
  require Attempt
  Attempt.execute tries: 3 do
    IO.puts "Hello world"
  end
```
## Topics for discussion

* The `Token Bucket` implementation creates a `GenServer` for each bucket and uses `Process.send_after/3` to add tokens to the bucket.  Is this the best approach?

* Part of the reason for using a timer-based approach to adding tokens is that it greatly simplifies token acquisition from a client application perspective.  `Attempt.Bucket.claim_token/2` will only return when it has a token or there is a timeout on the acquisition.  Requests are added to a queue when no tokens are available and the queue is processed every time a new token is added and a new claim request is received.  Its possible a selective receive strategy would be better.

* Currently when an exception is returned from the function but the retry policy defines it to be a `:return` classification (rather than a `:reraise` classification) the return is a tuple `{exception, stacktrace}`.  Its not clear thats the most meaninful return result.

## Todo

* [ ] Add Enumerable behaviour for the token bucket and the backoff strategy
* [ ] Implement the `!` version of `Attempt.run!/2`

## Installation

`Attempt` can be installed by adding `attempt` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:attempt, "~> 0.5.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/attempt](https://hexdocs.pm/attempt).

