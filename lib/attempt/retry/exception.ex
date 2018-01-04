defprotocol Attempt.Retry.Exception do
  @moduledoc """
  Classifies whether an exception raised during the
  function call is either `:return`, `:retry` or
  `:reraise`.
  """

  @fallback_to_any true
  def retriable?(exception)
end

defimpl Attempt.Retry.Exception, for: Any do
  def retriable?(_exception), do: :retry
end

defimpl Attempt.Retry.Exception, for: RuntimeError do
  def retriable?(_exception), do: :reraise
end

defimpl Attempt.Retry.Exception, for: ArgumentError do
  def retriable?(_exception), do: :reraise
end

defimpl Attempt.Retry.Exception, for: ArithmeticError do
  def retriable?(_exception), do: :reraise
end
