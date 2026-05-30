defmodule Todex.Repo do
  use Ecto.Repo,
    otp_app: :todex,
    adapter: Ecto.Adapters.Postgres
end
