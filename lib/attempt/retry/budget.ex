defmodule Attempt.Retry.Budget do
  @moduledoc """
  Defines the structure of a retry budget.

  The elements of a retry budget are:

  * `:tries` defines the maximum number of function
  executions are permitted before an error is
  returned.  The minimum is 1.

  * `:token_bucket` defines the token bucket used
  to throttle the rate of function execution

  * `:backkoff_strategy` defines the backoff strategy
  when retrying execution.  Any module that implements
  the `Attempt.Retry.Backoff` behaviour.  The default
  is `Attempt.Retry.Backoff.Default`
  """

  defstruct retry_policy: Attempt.Retry.Policy.Default,
            token_bucket: nil,
            tries: 1,
            current_try: 1,
            backoff_strategy: nil,
            last_sleep: 0,
            timeout: 5_000

  alias Attempt.{Bucket, Retry}

  @type t :: %Retry.Budget{
          retry_policy: module(),
          token_bucket: Bucket.t(),
          tries: non_neg_integer,
          current_try: non_neg_integer,
          backoff_strategy: module(),
          last_sleep: non_neg_integer,
          timeout: non_neg_integer
        }
end
