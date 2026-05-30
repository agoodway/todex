defmodule TodexWeb.RateLimitTest do
  use ExUnit.Case, async: false

  # RateLimit uses a named ETS table and a named GenServer, so tests must run
  # serially (async: false) and use unique IPs to avoid cross-test pollution.
  #
  # The global test config disables the limiter to prevent pollution of the
  # REST API test suite. Each test here re-enables it for its own duration.

  alias TodexWeb.RateLimit

  setup do
    Application.put_env(:todex, :rate_limit_enabled, true)

    on_exit(fn ->
      Application.put_env(:todex, :rate_limit_enabled, false)
    end)

    :ok
  end

  defp unique_ip do
    n = System.unique_integer([:positive])
    {rem(n, 256), rem(div(n, 256), 256), 1, 1}
  end

  test "allows requests under the limit" do
    ip = unique_ip()

    for _ <- 1..10 do
      assert :ok = RateLimit.check(ip)
    end
  end

  test "blocks requests over the limit within the same window" do
    ip = unique_ip()

    for _ <- 1..10 do
      assert :ok = RateLimit.check(ip)
    end

    assert {:error, :rate_limited} = RateLimit.check(ip)
  end

  test "different IPs have independent counters" do
    ip1 = unique_ip()
    ip2 = unique_ip()

    for _ <- 1..10 do
      assert :ok = RateLimit.check(ip1)
    end

    assert {:error, :rate_limited} = RateLimit.check(ip1)
    assert :ok = RateLimit.check(ip2)
  end

  test "returns 429 on rate-limited auth endpoints" do
    import Plug.Conn
    import Plug.Test

    # Use a conn with a specific remote_ip so we can exhaust its limit
    ip = unique_ip()
    opts = TodexWeb.Router.init([])

    for _ <- 1..10 do
      RateLimit.check(ip)
    end

    conn =
      conn(:post, "/api/auth/login", Jason.encode!(%{email: "a@b.com", password: "pw"}))
      |> put_req_header("content-type", "application/json")
      |> Map.put(:remote_ip, ip)
      |> TodexWeb.Router.call(opts)

    assert conn.status == 429

    assert Jason.decode!(conn.resp_body) == %{
             "error" => %{
               "code" => "rate_limited",
               "message" => "Too many requests",
               "details" => %{}
             }
           }
  end

  test "returns 429 on rate-limited register endpoint" do
    import Plug.Conn
    import Plug.Test

    ip = unique_ip()
    opts = TodexWeb.Router.init([])

    for _ <- 1..10 do
      RateLimit.check(ip)
    end

    conn =
      conn(:post, "/api/auth/register", Jason.encode!(%{email: "a@b.com", password: "pw"}))
      |> put_req_header("content-type", "application/json")
      |> Map.put(:remote_ip, ip)
      |> TodexWeb.Router.call(opts)

    assert conn.status == 429
  end
end
