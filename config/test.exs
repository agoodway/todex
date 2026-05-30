import Config

config :todex,
  swagger_ui_enabled: true,
  rate_limit_enabled: false

config :francis,
  bandit_opts: [port: 4002]

config :todex, Todex.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "todex_test#{System.get_env("MIX_TEST_PARTITION")}"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :todex, :jwt,
  issuer: "todex-test",
  audience: "todex-api-test",
  ttl_seconds: 86_400,
  secret: "test-secret-at-least-32-bytes-long"
