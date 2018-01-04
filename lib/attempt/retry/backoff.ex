defmodule Attempt.Retry.Backoff do
  @moduledoc """
  Defines a behaviour to implement retry backoff
  strategies.

  See https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/

  Implemented strategies are:

  * `Attempt.Retry.Backoff.None` which has no backoff delay.
  Speed of execution will be gated only by the configured token bucket

  * `Attempt.Retry.Backoff.Exponential` which implementd an exponential
  backoff to a maximum of 500ms

  * `Attempt.Retry.Backoff.ExponentialFullJitter` which randomises the
  backoff time from the exponential backoff to the maximum backoff

  * `Attempt.Retry.Backoff.ExponentialDecorrelatedJitter` which randomises
  the backoff between zero and a time calculated based on the last delay time

  See the relevant module for more information.  The default backoff strategy
  is `Attempt.Retry.Backoff.None`.

  """

  @doc """
  Returns the number of milliseconds to delay before the
  next retry
  """
  @callback delay(Retry.Budget.t()) :: {non_neg_integer, Retry.Budget.t()}
end
