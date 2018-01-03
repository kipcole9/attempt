defmodule Attempt.Retry.DefaultPolicy do
  @behaviour Attempt.Retry
  alias Attempt.Retry.Exception

  def action(:ok), do: :return
  def action({:ok, _}), do: :return
  def action(:error), do: :retry
  def action({:error, _}), do: :retry

  # Its an exception
  def action(%{__struct__: exception} = exception_type) do
    if function_exported?(exception, :exception, 1) do
      Exception.retriable?(exception_type)
    else
      :return
    end
  end

  # Anything else we consider is a return value
  def action(_any), do: :return
end
