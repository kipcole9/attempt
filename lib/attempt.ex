defmodule Attempt do
  @moduledoc """

  """

  alias Attempt.{Bucket, Retry}

  @doc """
  Implements a block form of `Attempt.run/2`.

  ## Examples

      iex> require Attempt
      ...> Attempt.execute tries: 3 do
      ...>   IO.puts "Welcome to Attempt"
      ...> end
      Hi
      :ok

  """
  defmacro execute(options, block) do
    if match?({:fn, _, _}, options) do
      quote do
        Attempt.run(unquote(options), unquote(block))
      end
    else
      block = block[:do]

      quote do
        Attempt.run(fn -> unquote(block) end, unquote(options))
      end
    end
  end

  defmacro execute(options) do
    {block, options} = Keyword.pop(options, :do)

    if Enum.empty?(options) do
      quote do
        Attempt.run(fn -> unquote(block) end, [])
      end
    else
      quote do
        Attempt.run(fn -> unquote(block) end, unquote(options))
      end
    end
  end

  @doc """
  Run a function in the context of a retry budget.

  A retry budget has several compoents:

  * a `token bucket` which acts to provide retry throttlnh for any retries

  * a `retry policy` which determines whether to return, retry or reraise

  * a `backoff` strategy which determines the retry backoff strategy

  * a maximum number of allowable `tries` that are performed when in an
  effort to generate a non-error return

  The given function will be executed until a successful return is delivered
  or the maximum number of tries is exceeded or if no token could be claimed.

  ## Arguments

  * `fun` is an anonymous function or function reference to be executed.

  * `options` is a keyword list of options to configure the retry budget

  ## Options

  * `:tries` is the number of times the function will be executed if an error
  is returned from the function

  * `:token_bucket` is the token bucket used to throttle the execution rate.
  Currently only one token bucket is implemented.  See `Attempt.Bucket.Token`

  * `:retry_policy` is a module that implements the `Attempt.Retry` behaviour
  to classify the return value from the `fun` as either `:return`, `:retry` or
  `reraise`.  The default `retry_policy` is `Attempt.Retry.DefaultPolicy`.

  * `:backoff` is a module that implements the `Attempt.Retry.Backoff`
  behaviour which is used to determine the backoff strategy for retries.

  ## Default options

  If not supplied the default options are:

  * `:tries` is `1`

  * `:token_bucket` is `Attempt.Bucket.Token.new(@default_bucket_name)`

  * `:retry_policy` is `Attempt.Retry,Policy.Default`

  * `:backoff` is `Attempt.Retry.Backoff.Exponential`

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

  """
  @spec run(function(), Keyword.t() | Retry.Budget.t()) :: any()
  def run(fun, options \\ [])

  def run(fun, options) when is_list(options) do
    options =
      default_options()
      |> Keyword.merge(options)
      |> Enum.into(%{})
      |> Map.put(:current_try, 1)
      |> maybe_start_default_bucket

    run(fun, struct(Retry.Budget, options))
  end

  def run(
        fun,
        %Retry.Budget{
          retry_policy: retry_policy,
          token_bucket: token_bucket,
          tries: max_tries,
          current_try: current_try
        } = budget
      ) do
    with {:ok, budget} <- backoff(budget),
         {:ok, _remaining_tokens} <- Bucket.claim_token(token_bucket, budget),
         result = execute_function(fun) do
      case retry_policy.action(result) do
        :return ->
          result

        :retry ->
          if current_try >= max_tries do
            result
          else
            run(fun, %Retry.Budget{budget | current_try: current_try + 1})
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
        {e, System.stacktrace()}
    end
  end

  defp backoff(budget) do
    delay = budget.backoff_strategy.delay(budget)
    if delay > 0, do: Process.sleep(delay)
    {:ok, %Retry.Budget{budget | last_sleep: delay}}
  end

  @default_bucket_name Attempt.Bucket.Token.Default
  @default_tries 1

  defp default_options do
    [
      tries: @default_tries,
      token_bucket: nil,
      retry_policy: Retry.Policy.Default
    ]
  end

  defp maybe_start_default_bucket(%{token_bucket: nil} = options) do
    case Bucket.Token.new(@default_bucket_name) do
      {:ok, bucket} ->
        %{options | token_bucket: bucket}

      {:error, {Attempt.TokenBucket.AlreadyStartedError, _}, bucket} ->
        %{options | token_bucket: bucket}
    end
  end

  defp maybe_start_default_bucket(options) do
    options
  end
end
