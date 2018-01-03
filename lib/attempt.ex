defmodule Attempt do
  @moduledoc """
  Documentation for Attempt.
  """

  @doc """
  Attempt to execute a function with a retry budget that comprises
  the number of times to try to execute the function and an optional
  rate-limiting token bucket.

  ## Options

  * :bucket defines the rate limiting bucket returned by `Bucket.Token.new/2`

  * :tries defines how many times to try execution.  The default is 1

  ## Successful completion

  The function is considered to have been successful if it returns:

  * :ok
  * {:ok, term()}

  ## Errors and Exceptions

  The function is retried up to the configured limits of the
  retry budged if returns:

  * :error

  * {:error, term()}

  * or it raises an exception.  Som exceptions are retriable so
  Attempt defines a protocol `Attempt.retriable?` and a default implementation
  that will return `false`.  Since exceptions are structs, implementers
  can implement their own `retriable?/1` implementation.

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

  def execute(fun, options \\ default_options()) do
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
      end
    end
  end

  defp execute_function(fun) do
    try do
      fun.()
    rescue
      e ->
        e
    end
  end

  @default_bucket :attempt_default_bucket
  @default_tries 1

  defp default_options do
    [
      tries: @default_tries,
      token_bucket: make_or_get_default_bucket(@default_bucket),
      retry_policy: Retry.DefaultPolicy
    ]
  end

  defp make_or_get_default_bucket(bucket) do
    if Process.whereis(bucket) do
      bucket
    else
      {:ok, bucket} = Bucket.Token.new(bucket)
      bucket
    end
  end
end
