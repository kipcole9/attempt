defmodule Attempt.Retry.Backoff do
  @moduledoc """
  Defines a behaviour to implement retry backoff
  strategies.

  See https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
  """

  @doc """
  Returns the number of milliseconds to delay before the
  next retry
  """
  @callback delay(Retry.Budget.t()) :: {non_neg_integer, Retry.Budget.t()}
end
