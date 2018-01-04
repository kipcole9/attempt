defmodule Attempt.Retry.Backoff.ExponentialFullJitter do
  @behaviour Attempt.Retry.Backoff
  alias Attempt.Retry

  @base_delay 0
  @max_delay 500

  def delay(%Retry.Budget{current_try: current_try}) do
    upper_range =
      min(@max_delay, :math.pow(current_try, 2) * @base_delay)
      |> trunc

    Enum.random(0..upper_range)
  end
end
