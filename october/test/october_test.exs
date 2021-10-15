defmodule OctoberTest do
  use ExUnit.Case
  doctest October

  test "greets the world" do
    assert October.hello() == :world
  end
end
