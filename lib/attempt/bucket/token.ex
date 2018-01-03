defmodule Attempt.Bucket.Token do
  @moduledoc """
  Implementation of a Token Bucket

  A token bucket provides a form of [rate limiting](https://en.wikipedia.org/wiki/Token_bucket)

  This implmentation is designed to allow for both
  synchronous and asynchronous token requests.  The
  intent is to simplify the higher level APIs by giving
  them a soft guarantee of token return.

  Since the implementation uses timers (via Process.send_after/3)
  neither the timing precision not the minimum time window
  are likely to be useful for all applications.

  The primary purpose of this token bucket is to
  support "longer liver" functions such as 3rd party
  API calls and calls to other external services
  like databases.

  ## Implementation

  * A bucket is defined to hold a maximum number of tokens

  * The token count is reduced by each call to `get_token/2`

  * When the token count reaches 0, the request is placed in
  a queue.

  * Every `:increment_every` milliseconds a new token is created.
  The increment is calculated as the `refill_every / bucket_size`
  so that the number of tokens is added in time consistent manner.

  * When the timer is reached and a new token is added the pending
  queue is processed
  """

  use GenServer
  require Logger

  defstruct burst_size:       10,       # Maximum number of tokens that can be consumed in a burst
            fill_rate:        3,        # Add a tken each per fill_rate milliseconds
            max_queue_length: 100,      # Don't allow the queue to expand forever
            increment_every:  nil,      # Increment the token count ever n milliseconds
            queue:            nil,      # The pending queue
            tokens:           nil,      # Available tokens
            pid:              nil       # The PID of this bucket

  @default_config @struct
  @default_timeout @struct.fill_rate

  def new(name, config \\ @default_config) do
    {:ok, pid} = start_link(name, config)
    %{config | pid: pid}
  end

  def start_link(name, config \\ @default_config) do
    config = %{config |
      tokens: config.burst_size,
      queue: :queue.new
    }
    GenServer.start_link(__MODULE__, config, name: name)
  end

  def init(config) do
    schedule_fill(config)
    {:ok, config}
  end

  def claim_token(bucket, options \\ []) do
    timeout = options[:timeout] || @default_timeout
    try do
      GenServer.call(bucket, :claim_token, timeout)
    catch :exit, reason ->
      {:error, reason}
    end
  end

  def claim_token!(bucket, options \\ []) do
    timeout = options[:timeout] || @default_timeout
    GenServer.call(bucket, :claim_token!, timeout)
  end

  # Callbacks

  def handle_call(:claim_token, _from, %{tokens: tokens, queue: queue} = bucket) when tokens > 0 do
    if :queue.len(queue) > 0 do
      process_queue(bucket)
    else
      bucket = decrement(bucket)
      {:reply, {:ok, bucket.tokens}, bucket}
    end
  end

  def handle_call(:claim_token, from, %{queue: queue} = bucket) do
    bucket = %{bucket | queue: :queue.in(from, queue)}
    {:noreply, bucket}
  end

  def handle_call(:claim_token!, _from, bucket) do
    if bucket.tokens > 0 do
      bucket = decrement(bucket)
      {:reply, {:ok, bucket.tokens}, bucket}
    else
      {:reply, {:error, 0}, bucket}
    end
  end

  def handle_info(:increment_bucket, bucket) do
    schedule_fill(bucket)
    bucket = %{bucket | tokens: min(bucket.tokens + 1, bucket.bucket_size)}
    {:noreply, process_queue(bucket)}
  end

  defp process_queue(%{queue: queue, tokens: tokens} = bucket) do
    if :queue.is_empty(queue) || tokens == 0 do
      bucket
    else
      bucket = decrement(bucket)
      {{_, pid}, new_queue} = :queue.out(queue)
      GenServer.reply pid, {:ok, bucket.tokens}
      process_queue(%{bucket | queue: new_queue})
    end
  end

  defp decrement(bucket) do
    %{bucket | tokens: bucket.tokens - 1}
  end

  defp schedule_fill(bucket) do
    Process.send_after(self(), :increment_bucket, bucket.fill_rate)
  end
end