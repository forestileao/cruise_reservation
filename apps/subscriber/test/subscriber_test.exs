defmodule SubscriberTest do
  use ExUnit.Case
  doctest Subscriber

  test "greets the world" do
    assert Subscriber.hello() == :world
  end
end
