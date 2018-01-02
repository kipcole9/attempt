defmodule AttemptTest do
  use ExUnit.Case
  doctest Attempt

  test "greets the world" do
    assert Attempt.hello() == :world
  end
end
