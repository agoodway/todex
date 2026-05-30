import Config

config :todex,
  swagger_ui_enabled: true

config :todex, :jwt,
  issuer: "todex",
  audience: "todex-api",
  ttl_seconds: 86_400,
  secret: System.get_env("TODEX_JWT_SECRET", "dev-only-insecure-secret-do-not-use-in-prod")

config :francis,
  dev: true,
  bandit_opts: [port: 6543]

config :todex, Todex.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "todex_dev"),
  stacktrace: true,
  pool_size: 10

config :open_api_spex, :cache_adapter, OpenApiSpex.Plug.NoneCache
