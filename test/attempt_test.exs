defmodule AttemptTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias Attempt.Bucket

  setup do
    on_exit fn ->
      Bucket.Token.stop(:test)
    end
  end

  test "create a token bucket" do
    assert Attempt.Bucket.Token.new(:test) ==
    {:ok,
     %Attempt.Bucket.Token{
       burst_size: 10,
       fill_rate: 3,
       max_queue_length: 100,
       name: :test,
       queue: nil,
       tokens: 0
     }}
  end

  test "creating an existing bucket returns an error" do
    {:ok, _bucket} = Attempt.Bucket.Token.new(:test)
    assert Attempt.Bucket.Token.new(:test) ==
      {:error,
       {Attempt.TokenBucket.AlreadyStartedError, "Bucket :test is already started"},
       %Attempt.Bucket.Token{
         burst_size: 10,
         fill_rate: 3,
         max_queue_length: 100,
         name: :test,
         queue: nil,
         tokens: 0
       }}
  end

  test "that we can return the bucket state" do
    {:ok, bucket} = Attempt.Bucket.Token.new(:test)
    assert Bucket.state(bucket) ==
      {:ok,
       %Attempt.Bucket.Token{
         burst_size: 10,
         fill_rate: 3,
         max_queue_length: 100,
         name: :test,
         queue: {[], []},
         tokens: 10
       }}
  end

  test "a simple excution with all default options" do
    assert Attempt.run(fn -> :ok end) == :ok
  end

  test "that we execute the right number of tries" do
    for tries <- 1..10 do
      output = capture_io fn ->
        assert Attempt.run(fn -> IO.puts("try"); :error end, tries: tries) == :error
      end
      assert tries == String.split(output, "\n", trim: true) |> Enum.count
    end
  end

  test "that we short circuit the tries if we get a ok return" do
    exit_on_count = 3
    Process.put(:count, 1)
    output = capture_io fn ->
      assert Attempt.run(fn ->
        IO.puts "Try"
        if Process.get(:count) == 3 do
          :ok
        else
          Process.put(:count, Process.get(:count) + 1)
          :error
        end
      end, tries: 5) == :ok
    end
    assert exit_on_count == Process.get(:count)
    assert exit_on_count == String.split(output, "\n", trim: true) |> Enum.count
  end

  test "that we timeout on the bucket if we exceed the burst" do
    tries = 5
    timeout = 500
    {:ok, bucket} = Attempt.Bucket.Token.new :test, fill_rate: 1_000, burst_size: tries - 1
    output = capture_io fn ->
      assert Attempt.run(fn ->
        IO.puts "Try"
        :error
      end, tries: tries, token_bucket: bucket, timeout: 500) ==
      {:error,
        {Attempt.TokenBucket.TimeoutError,
        "Token request for bucket :test timed out after #{timeout} milliseconds"}}
    end
    assert tries - 1 == String.split(output, "\n", trim: true) |> Enum.count
  end
end
