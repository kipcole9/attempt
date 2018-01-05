defmodule Attempt.Retry.Backoff.Exponential do
  @behaviour Attempt.Retry.Backoff
  alias Attempt.Retry

  @base_delay 10
  @max_delay 500

  def delay(%Retry.Budget{current_try: 1}), do: 0

  def delay(%Retry.Budget{current_try: current_try}) do
    min(@max_delay, :math.pow(current_try, 2) * @base_delay)
    |> trunc
  end
end
