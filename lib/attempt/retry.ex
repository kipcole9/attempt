defmodule Attempt.Retry do
  @callback action(term()) :: :return | :retry
end
