defmodule Attempt.Retry.Backoff.ExponentialDecorrelatedJitter do
  @behaviour Attempt.Retry.Backoff
  alias Attempt.Retry

  @base_delay 10
  @max_delay 500

  def delay(%Retry.Budget{current_try: 1}), do: 0

  def delay(%Retry.Budget{last_sleep: last_sleep}) do
    Enum.random(@base_delay..(last_sleep * 3))
    |> min(@max_delay)
  end
end
