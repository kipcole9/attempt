defmodule Attempt.Errors do
  @moduledoc false

  @doc false
  def no_tokens_error do
    {Attempt.TokenBucket.BucketError, "No tokens are available"}
  end

  @doc false
  def full_queue_error do
    {Attempt.TokenBucket.BucketError, "The request queue for tokens is full"}
  end

  @doc false
  def timeout_error(bucket_name, timeout) do
    {
      Attempt.TokenBucket.TimeoutError,
      "Token request for bucket #{inspect(bucket_name)} timed out after #{timeout} milliseconds"
    }
  end

  @doc false
  def already_started_error(config) do
    {
      Attempt.TokenBucket.BucketError,
      "Bucket #{inspect(config.name)} is already started"
    }
  end

  @doc false
  def unknown_bucket_error(name) do
    {
      Attempt.TokenBucket.BucketError,
      "Bucket #{inspect(name)} is not known"
    }
  end
end
