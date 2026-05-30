defmodule Todex.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one, name: Todex.Supervisor)
  end

  def children, do: children(nil)

  def children(_env) do
    [
      Todex.Repo,
      {Todex.Realtime, []},
      {TodexWeb.RateLimit, []},
      {TodexWeb.Router, []}
    ]
  end
end
