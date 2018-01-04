defmodule Attempt.Retry.Backoff.None do
  @behaviour Attempt.Retry.Backoff
  alias Attempt.Retry

  def delay(%Retry.Budget{}) do
    0
  end
end
