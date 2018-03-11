defmodule Attempt.Bucket.Infinite do
  @moduledoc """
  Implements an "infinte" bucket meaning there are
  no rate constraints and all token requests are
  returned successfully.
  """

  defstruct name: nil

  def new(bucket_name, _options \\ []) when is_atom(bucket_name) do
    {:ok, %__MODULE__{name: bucket_name}}
  end

  def claim_token(_bucket, _) do
    {:ok, :infinity}
  end

  def state(bucket) do
    {:ok, bucket}
  end

  def stop(_bucket_name) do
    :ok
  end

end
