defmodule Attempt.Retry do
  @callback action(term()) :: :return | :retry | :reraise
end
