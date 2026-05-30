import Config

config :todex,
  ecto_repos: [Todex.Repo],
  swagger_ui_enabled: false

config :todex, Todex.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :todex, :jwt,
  issuer: "todex",
  audience: "todex-api",
  ttl_seconds: 86_400,
  secret: System.get_env("TODEX_JWT_SECRET")

config :open_api_spex, :cache_adapter, OpenApiSpex.Plug.PutApiSpec

import_config "#{config_env()}.exs"
