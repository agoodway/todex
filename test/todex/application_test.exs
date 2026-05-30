defmodule Todex.ApplicationTest do
  use ExUnit.Case, async: true

  test "application child spec starts repo and router supervision tree" do
    children = Todex.Application.children(:test)

    assert Enum.any?(children, &match?(Todex.Repo, &1))
    assert Enum.any?(children, &match?({Todex.Realtime, []}, &1))
    assert Enum.any?(children, &match?({TodexWeb.RateLimit, []}, &1))
    assert Enum.any?(children, &match?({TodexWeb.Router, []}, &1))
  end

  test "application exposes production child spec without environment arguments" do
    assert Todex.Application.children() == Todex.Application.children(:test)
  end
end
