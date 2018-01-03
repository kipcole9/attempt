defprotocol Attempt.Retry.Exception do
  @fallback_to_any true
  def retriable?(exception)
end

defimpl Attempt.Retry.Exception, for: Any do
  def retriable?(exception), do: :retry
end

defimpl Attempt.Retry.Exception, for: RuntimeError do
  def retriable?(exception), do: :return
end

defimpl Attempt.Retry.Exception, for: ArgumentError do
  def retriable?(exception), do: :return
end
