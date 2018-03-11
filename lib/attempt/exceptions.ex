defmodule Attempt.TokenBucket.BucketError do
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

