defmodule Attempt.Retry.DefaultPolicy do
  @moduledoc """
  Defines the default retry policy.

  A retry policy classifies the returns from the
  called function into one of three classifications:

  * `:return` which indicates this is a successfull function
  call and the result should be returned

  * `:retry` which indicates the function call returned an
  error result but that retries should be attempted

  * `:reraise` which indicates that an exception was raised
  during the function execution and that the exception should
  be reraised.

  Developers may create their own retry policy modules by
  following the `Attempt.Retry` `@behaviour`.

  """

  @behaviour Attempt.Retry
  alias Attempt.Retry

  def action(:ok), do: :return
  def action({:ok, _}), do: :return
  def action(:error), do: :retry
  def action({:error, _}), do: :retry

  def action({exception, _stracktrace}) do
    if Exception.exception?(exception) do
      Retry.Exception.retriable?(exception)
    else
      :return
    end
  end

  def action(_return) do
    :return
  end

end
