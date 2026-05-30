import Config

if config_env() == :prod do
  database_url = System.fetch_env!("DATABASE_URL")
  jwt_secret = System.fetch_env!("TODEX_JWT_SECRET")

  if byte_size(jwt_secret) < 32 do
    raise "TODEX_JWT_SECRET must be at least 32 bytes (got #{byte_size(jwt_secret)}). " <>
            "Generate a strong one with: `openssl rand -base64 48` or " <>
            "`:crypto.strong_rand_bytes(48) |> Base.encode64()`."
  end

  config :francis,
    bandit_opts: [port: String.to_integer(System.get_env("PORT", "4000"))]

  config :todex, Todex.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    ssl: System.get_env("ECTO_SSL", "true") == "true"

  config :todex, :jwt,
    issuer: "todex",
    audience: "todex-api",
    ttl_seconds: String.to_integer(System.get_env("TODEX_JWT_TTL_SECONDS", "86400")),
    secret: jwt_secret
end
