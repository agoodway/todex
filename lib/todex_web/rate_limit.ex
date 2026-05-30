defmodule TodexWeb.RateLimit do
  @moduledoc """
  ETS-backed fixed-window rate limiter for auth endpoints.

  Tracks request counts per IP address within a fixed 60-second window.
  Each new window starts when the first request arrives in that window.

  Configurable via application environment:
    - `:rate_limit_enabled` (boolean, default `true`) — set to `false` to
      bypass all limiting (useful in test).
    - `:rate_limit_max_requests` (integer, default `10`) — requests allowed
      per window.
  """

  use GenServer

  @table :todex_rate_limit
  @window_ms 60_000

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Checks whether the given IP (as a tuple or string) is within the rate limit.

  Returns `:ok` if the request is allowed, or `{:error, :rate_limited}` if
  the limit has been exceeded. Returns `:ok` immediately when the limiter is
  disabled via config.
  """
  def check(ip) do
    if Application.get_env(:todex, :rate_limit_enabled, true) do
      do_check(ip)
    else
      :ok
    end
  end

  defp do_check(ip) do
    max_requests = Application.get_env(:todex, :rate_limit_max_requests, 10)
    now = System.monotonic_time(:millisecond)

    # Atomically increment the counter, inserting a default record {key, 0, now}
    # if no entry exists yet. The returned value is the new count after increment.
    new_count = :ets.update_counter(@table, ip, {2, 1}, {ip, 0, now})

    # Read back the stored window start to check if the window has expired.
    case :ets.lookup(@table, ip) do
      [{^ip, _count, window_start}] when now - window_start >= @window_ms ->
        # Window has expired — reset atomically and allow the request.
        :ets.insert(@table, {ip, 1, now})
        :ok

      _ ->
        if new_count <= max_requests do
          :ok
        else
          {:error, :rate_limited}
        end
    end
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @window_ms

    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @window_ms)
  end
end
