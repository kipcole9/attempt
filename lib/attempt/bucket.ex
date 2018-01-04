defprotocol Attempt.Bucket do

  @type t :: struct()

  @fallback_to_any true

  @doc """
  Claim a token from a token bucket
  """
  def claim_token(bucket, options)

  @doc """
  Return the state of the token bucket
  """
  def state(bucket)
end

defimpl Attempt.Bucket, for: Any do
  def claim_token(bucket, options), do: bucket.__struct__.claim_token(bucket, options)
  def state(bucket), do: bucket.__struct__.state(bucket)
end
