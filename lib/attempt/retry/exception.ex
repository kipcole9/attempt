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

if Code.ensure_loaded?(Ecto) do
  defimpl Attempt.Retry.Exception, for: Ecto.Query.CastError do
    def retriable?(_exception), do: :return
  end

  defimpl Attempt.Retry.Exception, for: Ecto.Query.CompileError do
    def retriable?(_exception), do: :return
  end

  defimpl Attempt.Retry.Exception, for: Ecto.QueryError do
    def retriable?(_exception), do: :return
  end

  defimpl Attempt.Retry.Exception, for: Ecto.SubQueryError do
    def retriable?(_exception), do: :return
  end

  defimpl Attempt.Retry.Exception, for: Ecto.InvalidChangesetError do
    def retriable?(_exception), do: :return
  end
end

# TODO Some exceptions should retry ... need to decide what they
# are - especially lock contention s
if Code.ensure_loaded?(Postgrex) do
  defimpl Attempt.Retry.Exception, for: Postgrex.Error do
    def retriable?(_exception), do: :return
  end
end

if Code.ensure_loaded?(DBConnection) do
  defimpl Attempt.Retry.Exception, for: DBConnection.ConnectionError do
    def retriable?(_exception), do: :retry
  end

  defimpl Attempt.Retry.Exception, for: DBConnection.TransactionError do
    def retriable?(_exception), do: :reraise
  end
end
