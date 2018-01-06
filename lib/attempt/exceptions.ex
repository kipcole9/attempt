defmodule Attempt.TokenBucket.FullTokenQueueError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Attempt.TokenBucket.NoTokensAvailableError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Attempt.TokenBucket.TimeoutError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Attempt.TokenBucket.AlreadyStartedtError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end
