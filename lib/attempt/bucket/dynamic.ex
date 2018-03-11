defmodule Attempt.Bucket.Dynamic do
  @moduledoc """
  Implementation of a Dynamic Token Bucket

  This token bucket is designed to maximise
  throughput without overloading the service
  it is protecting.

  For applications that require rate limiting
  the token bucket `Attempt.Bucket.Token` is
  recommended.

  The Dynamic bucket maintains in its state the
  currenct performance of the service it is
  protecting by treating the `claim_token/1` call
  as a proxy for service performance. Periodically
  the number of requests per second is updated
  and the bucket parameters adjusted to maximise
  througput without overloading the external
  service.

  In addition Dynamic bucket provides a mechanism
  to prevent retry storms.  It does this by limiting
  the number of retries as a percentage of overall
  requests.  Therefore as the failure rate goes up,
  the number of retries will be throttled since
  overall throughput will drop.
  """

  use GenServer
  alias Attempt.Bucket
  alias Attempt.Retry.Budget

  require Logger
  import Attempt.Errors
  import Supervisor.Spec

  defstruct name: nil,
            # Add a token each per fill_rate milliseconds
            fill_rate: 3,
            # Don't allow the queue to expand forever
            max_queue_length: 100,
            # The pending queue
            queue: nil,
            # Available tokens
            tokens: 0,
            # Maximum number of tokens that can be consumed in a burst
            burst_size: 10,
            # Number of first requests
            first_request_count: 0,
            # Number of retry requests
            retry_request_count: 0,
            # Calculate performance over n milliseconds
            performance_window: 2_000,
            # Maximum percentage of retries
            retry_percentage: 0.05

  @type t :: struct()
  @default_config @struct
  @default_timeout 5_000

  @spec new(atom(), Keyword.t() | Bucket.Token.t()) ::
          {:ok, Bucket.Token.t()} | {:error, {Exception.t(), String.t()}}

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

  @spec new(atom(), Keyword.t() | Bucket.Token.t()) :: {:ok, Bucket.Token.t()} | no_return()
  def new!(name, config) do
    case new(name, config) do
      {:ok, bucket} -> bucket
      error -> raise "Couldn't start bucket #{inspect(config.token_bucket)}: #{inspect(error)}"
    end
  end

  @spec state(Token.Bucket.t()) :: {:ok, non_neg_integer} | {:error, {Exception.t(), String.t()}}
  def state(bucket) do
    GenServer.call(bucket.name, :state)
  end

  def start_link(name, bucket \\ @default_config) do
    bucket = %{bucket | tokens: bucket.burst_size, queue: :queue.new()}
    GenServer.start_link(__MODULE__, bucket, name: name)
  end

  @spec stop(atom() | Retry.Budget.t() | Bucket.Token.t()) ::
          :ok | {:error, {Exception.t(), String.t()}}

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
