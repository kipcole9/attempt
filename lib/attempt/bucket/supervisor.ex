defmodule Attempt.Bucket.Supervisor do
  use DynamicSupervisor

  def start_link do
    start_link([])
  end

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
