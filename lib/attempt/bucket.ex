defprotocol Attempt.Bucket do
  @type t :: struct()

  @fallback_to_any true

  @doc """
  Create and start a new bucket
  """
  def new(bucket, options)

  @doc """
  Claim a token from a token bucket
  """
  def claim_token(bucket, options)

  @doc """
  Return the state of the token bucket
  """
  def state(bucket)

  @doc """
  Stop the token bucket process
  """
  def stop(bucket)
end

defimpl Attempt.Bucket, for: Any do
  def new(bucket, options), do: bucket.__struct__.new(bucket, options)
  def claim_token(bucket, options), do: bucket.__struct__.claim_token(bucket, options)
  def state(bucket), do: bucket.__struct__.state(bucket)
  def stop(bucket), do: bucket.__struct__.stop(bucket)
end

