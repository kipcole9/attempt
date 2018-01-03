defprotocol Attempt.Bucket do
  @fallback_to_any true
  def claim_token(bucket, options)
end

defimpl Attempt.Bucket, for: Any do
  def claim_token(bucket, options), do: claim_token(bucket, options)
end