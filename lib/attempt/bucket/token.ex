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
  alias Attempt.Bucket
  alias Attempt.Retry.Budget

  require Logger
  import Attempt.Errors
  import Supervisor.Spec

  # Maximum number of tokens that can be consumed in a burst
  defstruct burst_size: 10,
            # Add a token each per fill_rate milliseconds
            fill_rate: 3,
            # Don't allow the queue to expand forever
            max_queue_length: 100,
            # The pending queue
            queue: nil,
            # Available tokens
            tokens: 0,
            # The name of this bucket
            name: nil

  @default_config @struct
  @default_timeout 5_000

  def new(name, config \\ @default_config)

  def new(name, config) when is_atom(name) and is_list(config) do
    config =
      @default_config
      |> Map.delete(:__struct__)
      |> Map.to_list()
      |> Keyword.merge(config)
      |> Enum.into(%{})

    new(name, struct(__MODULE__, config))
  end

  def new(name, %Bucket.Token{} = config) when is_atom(name) do
    config = %Bucket.Token{config | name: name}
    bucket_worker = worker(__MODULE__, [name, config])

    case DynamicSupervisor.start_child(Bucket.Supervisor, bucket_worker) do
      {:ok, _pid} -> {:ok, config}
      {:error, {:already_started, _}} -> {:error, already_started_error(config), config}
    end
  end

  def new!(name, config) do
    case new(name, config) do
      {:ok, bucket} -> bucket
      error -> raise "Couldn't start bucket #{inspect(config.token_bucket)}: #{inspect(error)}"
    end
  end

  def state(bucket) do
    GenServer.call(bucket.name, :state)
  end

  def start_link(name, bucket \\ @default_config) do
    bucket = %{bucket | tokens: bucket.burst_size, queue: :queue.new()}
    GenServer.start_link(__MODULE__, bucket, name: name)
  end

  def stop(name) when is_atom(name) do
    if pid = Process.whereis(name) do
      DynamicSupervisor.terminate_child(Bucket.Supervisor, pid)
    else
      {:error, unknown_bucket_error(name)}
    end
  end

  def stop(%Budget{token_bucket: %Bucket.Token{name: name}}) do
    stop(name)
  end

  def stop(%Bucket.Token{name: name}) do
    stop(name)
  end

  def init(budget) do
    schedule_increment(budget)
    {:ok, budget}
  end

  def claim_token(bucket, %Budget{} = budget) do
    timeout = budget.timeout || @default_timeout

    try do
      GenServer.call(bucket.name, :claim_token, timeout)
    catch
      :exit, {:timeout, {GenServer, :call, [bucket_name, :claim_token, timeout]}} ->
        {:error, timeout_error(bucket_name, timeout)}
    end
  end

  def claim_token!(bucket, %Budget{} = budget) do
    timeout = budget.timeout || @default_timeout
    GenServer.call(bucket, :claim_token!, timeout)
  end

  # Callbacks

  def handle_call(:claim_token, from, %{tokens: tokens} = bucket) when tokens > 0 do
    bucket = process_queue(bucket)

    if bucket.tokens > 0 do
      bucket = decrement(bucket)
      {:reply, {:ok, bucket.tokens}, bucket}
    else
      handle_call(:claim_token, from, bucket)
    end
  end

  def handle_call(:claim_token, from, %{queue: queue} = bucket) do
    if :queue.len(queue) >= bucket.max_queue_length do
      {:reply, {:error, full_queue_error()}, bucket}
    else
      bucket = %{bucket | queue: :queue.in(from, queue)}
      {:noreply, bucket}
    end
  end

  def handle_call(:claim_token!, _from, bucket) do
    if bucket.tokens > 0 do
      bucket = decrement(bucket)
      {:reply, {:ok, bucket.tokens}, bucket}
    else
      {:reply, {:error, no_tokens_error()}, bucket}
    end
  end

  def handle_call(:state, _from, bucket) do
    {:reply, {:ok, bucket}, bucket}
  end

  def handle_info(:increment_bucket, bucket) do
    schedule_increment(bucket)
    bucket = %{bucket | tokens: min(bucket.tokens + 1, bucket.burst_size)}
    {:noreply, process_queue(bucket)}
  end

  defp process_queue(%{queue: queue, tokens: tokens} = bucket) do
    if :queue.is_empty(queue) || tokens == 0 do
      bucket
    else
      bucket = decrement(bucket)
      {{:value, pid}, new_queue} = :queue.out(queue)
      GenServer.reply(pid, {:ok, bucket.tokens})
      process_queue(%{bucket | queue: new_queue})
    end
  end

  defp decrement(bucket) do
    %{bucket | tokens: bucket.tokens - 1}
  end

  defp schedule_increment(bucket) do
    Process.send_after(self(), :increment_bucket, bucket.fill_rate)
  end

end
