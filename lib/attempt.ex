defmodule Attempt do
  @moduledoc """
  ## Limitations

  This implementation has some limitations that will be progressively
  removed:

  * No backoff strategy is employed for the retry, retries are controlled
  by the configured token bucket.

  * No jitter is introduced in the bucket algorithm

  * No leaky bucket token implementation.  The provided token bucket
  implementation allows for a burst of invokations up to the overall
  bucket size but it maintains an average execution rate.  A leaky bucket
  token implementation alternative would not allow a burst rate which
  in some cases would be a better strategy.
  """

  alias Attempt.{Bucket, Retry}

  @doc """
  Execute a function in the context of a retry budget.

  A retry budget has two compoents:

  * a `token bucket` which acts to provide retry throttlnh for any retries

  * a number of allowable `retries` that are performed when a failure exit is
    detected from the   function

  The given function will be executed until a successful return is detected
  or the maximum number of tries is exceeded or if no token could be claimed.

  ## Arguments

  * `fun` is an anonymous function or function reference to be executed.

  * `options` is a keyword list of options to configure the retry budget

  ## Options

  * `tries` is the number of times the function will be executed if an error
  is returned from the function

  * `token_bucket` is the token bucket used to throttle the execution rate.
  Currently only one token bucket is implemented.  See `Attempt.Bucket.Token`

  * `retry_policy` is a module that implements the `Attempt.Retry` behaviour
  to classify the return value from the `fun` as either `:return`, `:retry` or
  `reraise`.  The default `retry_policy` is `Attempt.Retry.DefaultPolicy`.

  ## Default options

  If not supplied the default options are:

  * `:tries` is `1`

  * `:token_bucket` is `Attempt.Bucket.Token.new(@default_bucket_name)`

  * `:retry_policy` is `Attempt.Retry,DefaultPolicy`

  ## Retry policy actions

  In order to ascertain whether a function should be retried each return value
  needs to be classified.  The classification is the responsibility of the
  `:retry_policy` module.  Three classifications are available:

  * `:return` means that the return value of the function is considered
  a success and it returned to the called

  * `:retry` means that a failure return was detected but that the failure
  is considered transient and is therefore eligble to be retried

  * `:reraise` means that an exception was detected and the execption is not
  considered transient.  Therefore the exception should be re-raised.

  See also `Attempt.Retry.Exception` which defines a protocol for determining
  the classification of exceptions and `Attempt.Retry.DefaultPolicy` which
  implements the default classifier.

  ## Examples

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

  """
  def execute(fun, options \\ []) do
    options =
      default_options()
      |> Keyword.merge(options)
      |> Enum.into(%{})
      |> maybe_start_default_bucket

    execute(fun, options[:retry_policy], options[:token_bucket], options[:tries], 1, options)
  end

  defp execute(fun, retry_policy, token_bucket, max_tries, current_try, options) do
    with {:ok, _remaining_tokens} <- Bucket.claim_token(token_bucket, options),
         result = execute_function(fun) do
      case retry_policy.action(result) do
        :return ->
          result

        :retry ->
          if current_try >= max_tries do
            result
          else
            execute(fun, retry_policy, token_bucket, max_tries, current_try + 1, options)
          end

        :reraise ->
          {exception, stacktrace} = result
          Kernel.reraise(exception, stacktrace)
      end
    end
  end

  defp execute_function(fun) do
    try do
      fun.()
    rescue
      e ->
        {e, System.stacktrace}
    end
  end

  @default_bucket_name :attempt_default_bucket
  @default_tries 1

  defp default_options do
    [
      tries: @default_tries,
      token_bucket: nil,
      retry_policy: Retry.DefaultPolicy
    ]
  end

  defp maybe_start_default_bucket(%{token_bucket: nil} = options) do
    case Bucket.Token.new(@default_bucket_name) do
      {:ok, bucket} -> %{options | token_bucket: bucket}
      {:error, {:already_started, _}, bucket} -> %{options | token_bucket: bucket}
    end
  end

  defp maybe_start_default_bucket(options) do
    options
  end
end
