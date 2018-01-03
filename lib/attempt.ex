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
  Attmept defined a protocol `Attempt.retriable?` and a default implementation
  that will return `false`.  Since exceptions are structs, implementers
  can implement their own `retriable?/1` implementation.

  ## Limitations

  This implementation has some limitations that will be progressively
  removed:

  * No backoff strategy is employed for the retry, retires are controlled
  by the configured token bucket.

  * No jitter is introduced in the bucket algorithm

  * No leaky bucket token implementation.  The provided token bucket
  implementation allows for a burst of invokations up to the overall
  bucket size but it maintains an average execution rate.  A leaky bucket
  token implementation alternative would not allow for a burst rate
  """

  alias Attempt.Bucket

  def execute(options, fun) do
    with {:ok, _} <- Bucket.claim_token(options[:token_bucket], options) do

    end
  end

  @default_bucket :attempt_default_bucket

  defp default_options do
    [
      tries: 5,
      token_bucket: Attempt.Bucket.Token.new(@default_bucket, burst_size: 10, fill_rate: 1_000)
    ]
  end
end
