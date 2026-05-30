# Francis OpenAPI Todex API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a PostgreSQL-backed authenticated Todex API in Francis with REST, OpenAPI docs, dev Swagger UI, and a WebSocket command API.

**Architecture:** Keep Francis as the HTTP/WebSocket boundary and move domain behavior into `Todex.Accounts` and `Todex.Todos`. PostgreSQL is the source of truth via Ecto; WebSocket handlers call the same contexts as REST and broadcast per-user events through a small registry. OpenAPI is built manually with `open_api_spex` because Francis routes are not Phoenix controller routes.

**Tech Stack:** Elixir 1.18, Francis, Plug, Bandit, Ecto SQL, PostgreSQL/Postgrex, Bcrypt, Joken, OpenApiSpex, Jason, ExUnit, Plug.Test.

**Git note:** `/Users/tbrewer/projects/goodway/todex` is not currently a git repository. Commit steps below are intentional checkpoints. If git is still unavailable, record the checkpoint in the task log instead of running `git commit`.

---

## File Structure

- Modify: `mix.exs` to add Ecto, PostgreSQL, password hashing, JWT, OpenApiSpex, and test support dependencies.
- Modify: `.formatter.exs` to import OpenApiSpex formatting rules.
- Modify: `config/config.exs`, `config/dev.exs`, `config/test.exs`, `config/prod.exs` for repo, Francis, JWT, OpenApiSpex, and database settings.
- Create: `lib/todex/application.ex` to supervise `Todex.Repo`, `Todex.Realtime`, and the Francis router.
- Create: `lib/todex/repo.ex` for the Ecto repository.
- Replace: `lib/todex/todex.ex` with a compatibility module or remove it from the application entrypoint.
- Create: `lib/todex/accounts/user.ex`, `lib/todex/accounts/auth_token.ex`, `lib/todex/accounts.ex` for users and auth.
- Create: `lib/todex/todos/list.ex`, `lib/todex/todos/task.ex`, `lib/todex/todos.ex` for list/task domain logic.
- Create: `lib/todex_web/router.ex` for Francis REST and WebSocket routes.
- Create: `lib/todex_web/auth_plug.ex`, `lib/todex_web/errors.ex`, `lib/todex_web/json.ex` for boundary concerns.
- Create: `lib/todex_web/realtime/command_handler.ex` and `lib/todex/realtime.ex` for socket command dispatch and broadcasting.
- Create: `lib/todex_web/api_spec.ex` and `lib/todex_web/schemas.ex` for manual OpenAPI spec generation.
- Create migrations in `priv/repo/migrations/` for users, auth tokens, lists, and tasks.
- Create tests in `test/support/`, `test/todex/`, and `test/todex_web/`.

---

### Task 1: Project Dependencies, Repo, And Application Supervision

**Files:**
- Modify: `mix.exs`
- Modify: `.formatter.exs`
- Modify: `config/config.exs`
- Modify: `config/dev.exs`
- Modify: `config/test.exs`
- Modify: `config/prod.exs`
- Create: `lib/todex/application.ex`
- Create: `lib/todex/repo.ex`
- Modify: `lib/todex/todex.ex`

- [ ] **Step 1: Write the failing supervision test**

Create `test/todex/application_test.exs`:

```elixir
defmodule Todex.ApplicationTest do
  use ExUnit.Case, async: true

  test "application child spec starts repo and router supervision tree" do
    children = Todex.Application.children(:test)

    assert Enum.any?(children, &match?(Todex.Repo, &1))
    assert Enum.any?(children, &match?({Todex.Realtime, []}, &1))
    assert Enum.any?(children, &match?({TodexWeb.Router, []}, &1))
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `unbuffer mix test test/todex/application_test.exs`

Expected: FAIL with `Todex.Application` undefined.

- [ ] **Step 3: Add dependencies and application module**

Update `mix.exs`:

```elixir
defmodule Todex.MixProject do
  use Mix.Project

  def project do
    [
      app: :todex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [mod: {Todex.Application, []}, extra_applications: [:logger, :runtime_tools]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:francis, "~> 0.2"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:joken, "~> 2.6"},
      {:open_api_spex, "~> 3.21"}
    ]
  end
end
```

Update `.formatter.exs`:

```elixir
[
  import_deps: [:open_api_spex],
  inputs: ["{config,lib,test}/**/*.{ex,exs}"]
]
```

Create `lib/todex/repo.ex`:

```elixir
defmodule Todex.Repo do
  use Ecto.Repo,
    otp_app: :todex,
    adapter: Ecto.Adapters.Postgres
end
```

Create `lib/todex/application.ex`:

```elixir
defmodule Todex.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = children(Mix.env())
    Supervisor.start_link(children, strategy: :one_for_one, name: Todex.Supervisor)
  end

  def children(_env) do
    [
      Todex.Repo,
      {Todex.Realtime, []},
      {TodexWeb.Router, []}
    ]
  end
end
```

Replace `lib/todex/todex.ex` with:

```elixir
defmodule Todex do
  @moduledoc "Todex application namespace."
end
```

- [ ] **Step 4: Configure repo and Francis**

Update `config/config.exs`:

```elixir
import Config

config :todex,
  ecto_repos: [Todex.Repo]

config :todex, Todex.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :todex, :jwt,
  issuer: "todex",
  audience: "todex-api",
  ttl_seconds: 86_400,
  secret: System.get_env("TODEX_JWT_SECRET", "dev-only-change-me")

config :open_api_spex, :cache_adapter, OpenApiSpex.Plug.PutApiSpec

import_config "#{config_env()}.exs"
```

Update `config/dev.exs`:

```elixir
import Config

config :francis,
  dev: true,
  bandit_opts: [port: 4000]

config :todex, Todex.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "todex_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :open_api_spex, :cache_adapter, OpenApiSpex.Plug.NoneCache
```

Update `config/test.exs`:

```elixir
import Config

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
```

Update `config/prod.exs`:

```elixir
import Config

database_url = System.fetch_env!("DATABASE_URL")
jwt_secret = System.fetch_env!("TODEX_JWT_SECRET")

config :francis,
  bandit_opts: [port: String.to_integer(System.get_env("PORT", "4000"))]

config :todex, Todex.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
  ssl: System.get_env("ECTO_SSL", "false") == "true"

config :todex, :jwt,
  issuer: "todex",
  audience: "todex-api",
  ttl_seconds: String.to_integer(System.get_env("TODEX_JWT_TTL_SECONDS", "86400")),
  secret: jwt_secret
```

- [ ] **Step 5: Fetch deps and run test**

Run: `mix deps.get`

Expected: dependencies resolve successfully.

Run: `unbuffer mix test test/todex/application_test.exs`

Expected: test compiles, then may fail because `Todex.Realtime` and `TodexWeb.Router` do not exist yet.

- [ ] **Step 6: Add temporary compile stubs**

Create `lib/todex/realtime.ex`:

```elixir
defmodule Todex.Realtime do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(state), do: {:ok, state}
end
```

Create `lib/todex_web/router.ex`:

```elixir
defmodule TodexWeb.Router do
  use Francis

  get("/", fn _conn -> %{ok: true} end)

  unmatched(fn _conn -> %{error: %{code: "not_found", message: "Not found", details: %{}}} end)
end
```

- [ ] **Step 7: Run test to verify it passes**

Run: `unbuffer mix test test/todex/application_test.exs`

Expected: PASS.

- [ ] **Step 8: Checkpoint**

If git is initialized, run:

```bash
git add mix.exs mix.lock .formatter.exs config lib test/todex/application_test.exs
git commit -m "feat: add ecto application foundation"
```

If git is unavailable, note: `Checkpoint: Ecto application foundation complete`.

---

### Task 2: Database Migrations, Schemas, And Test Sandbox

**Files:**
- Create: `priv/repo/migrations/*_create_users.exs`
- Create: `priv/repo/migrations/*_create_auth_tokens.exs`
- Create: `priv/repo/migrations/*_create_lists.exs`
- Create: `priv/repo/migrations/*_create_tasks.exs`
- Create: `lib/todex/accounts/user.ex`
- Create: `lib/todex/accounts/auth_token.ex`
- Create: `lib/todex/todos/list.ex`
- Create: `lib/todex/todos/task.ex`
- Create: `test/support/data_case.ex`
- Modify: `test/test_helper.exs`
- Test: `test/todex/schema_test.exs`

- [ ] **Step 1: Write failing schema tests**

Create `test/support/data_case.ex`:

```elixir
defmodule Todex.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Todex.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Todex.DataCase
    end
  end

  setup tags do
    Todex.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Todex.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
```

Update `test/test_helper.exs`:

```elixir
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Todex.Repo, :manual)
```

Create `test/todex/schema_test.exs`:

```elixir
defmodule Todex.SchemaTest do
  use Todex.DataCase, async: true

  alias Todex.Accounts.User
  alias Todex.Todos.{List, Task}

  test "user changeset requires email and password" do
    changeset = User.registration_changeset(%User{}, %{})

    assert %{email: ["can't be blank"], password: ["can't be blank"]} = errors_on(changeset)
  end

  test "list changeset requires name" do
    changeset = List.changeset(%List{}, %{})

    assert %{name: ["can't be blank"]} = errors_on(changeset)
  end

  test "task changeset requires title, user, and list" do
    changeset = Task.changeset(%Task{}, %{})

    assert %{title: ["can't be blank"], user_id: ["can't be blank"], list_id: ["can't be blank"]} = errors_on(changeset)
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run: `unbuffer mix test test/todex/schema_test.exs`

Expected: FAIL because schema modules do not exist.

- [ ] **Step 3: Create schemas**

Create `lib/todex/accounts/user.ex`:

```elixir
defmodule Todex.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 8, max: 72)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp normalize_email(nil), do: nil
  defp normalize_email(email), do: email |> String.trim() |> String.downcase()

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
```

Create `lib/todex/accounts/auth_token.ex`:

```elixir
defmodule Todex.Accounts.AuthToken do
  use Ecto.Schema
  import Ecto.Changeset

  alias Todex.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "auth_tokens" do
    field :token_hash, :string
    field :expires_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:user_id, :token_hash, :expires_at])
    |> validate_required([:user_id, :token_hash, :expires_at])
    |> unique_constraint(:token_hash)
  end
end
```

Create `lib/todex/todos/list.ex`:

```elixir
defmodule Todex.Todos.List do
  use Ecto.Schema
  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Todos.Task

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lists" do
    field :name, :string
    field :icon, :string
    field :color, :string
    field :position, :integer, default: 0
    field :is_default, :boolean, default: false

    belongs_to :user, User
    has_many :tasks, Task

    timestamps(type: :utc_datetime)
  end

  def changeset(list, attrs) do
    list
    |> cast(attrs, [:user_id, :name, :icon, :color, :position, :is_default])
    |> validate_required([:user_id, :name])
    |> validate_length(:name, min: 1, max: 80)
    |> unique_constraint([:user_id, :name])
  end
end
```

Create `lib/todex/todos/task.ex`:

```elixir
defmodule Todex.Todos.Task do
  use Ecto.Schema
  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Todos.List

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses [:active, :completed]

  schema "tasks" do
    field :title, :string
    field :notes, :string
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :due_date, :date
    field :completed_at, :utc_datetime
    field :position, :integer, default: 0

    belongs_to :user, User
    belongs_to :list, List

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:user_id, :list_id, :title, :notes, :status, :due_date, :completed_at, :position])
    |> validate_required([:user_id, :list_id, :title])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:list_id)
  end
end
```

- [ ] **Step 4: Create migrations**

Run:

```bash
mix ecto.gen.migration create_users
mix ecto.gen.migration create_auth_tokens
mix ecto.gen.migration create_lists
mix ecto.gen.migration create_tasks
```

Use this migration body for users:

```elixir
def change do
  create table(:users, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :email, :citext, null: false
    add :password_hash, :string, null: false

    timestamps(type: :utc_datetime)
  end

  execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"
  create unique_index(:users, [:email])
end
```

Use this migration body for auth tokens:

```elixir
def change do
  create table(:auth_tokens, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
    add :token_hash, :string, null: false
    add :expires_at, :utc_datetime, null: false

    timestamps(type: :utc_datetime, updated_at: false)
  end

  create index(:auth_tokens, [:user_id])
  create unique_index(:auth_tokens, [:token_hash])
end
```

Use this migration body for lists:

```elixir
def change do
  create table(:lists, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
    add :name, :string, null: false
    add :icon, :string
    add :color, :string
    add :position, :integer, null: false, default: 0
    add :is_default, :boolean, null: false, default: false

    timestamps(type: :utc_datetime)
  end

  create index(:lists, [:user_id])
  create unique_index(:lists, [:user_id, :name])
end
```

Use this migration body for tasks:

```elixir
def change do
  create table(:tasks, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
    add :list_id, references(:lists, type: :binary_id, on_delete: :restrict), null: false
    add :title, :string, null: false
    add :notes, :text
    add :status, :string, null: false, default: "active"
    add :due_date, :date
    add :completed_at, :utc_datetime
    add :position, :integer, null: false, default: 0

    timestamps(type: :utc_datetime)
  end

  create index(:tasks, [:user_id])
  create index(:tasks, [:list_id])
  create index(:tasks, [:user_id, :status])
  create index(:tasks, [:user_id, :due_date])
end
```

- [ ] **Step 5: Create and migrate test database**

Run: `MIX_ENV=test mix ecto.create`

Expected: database created or already exists.

Run: `MIX_ENV=test mix ecto.migrate`

Expected: migrations complete.

- [ ] **Step 6: Run schema tests**

Run: `unbuffer mix test test/todex/schema_test.exs`

Expected: PASS.

- [ ] **Step 7: Checkpoint**

If git is initialized, run:

```bash
git add priv/repo/migrations lib/todex/accounts lib/todex/todos test/support test/test_helper.exs test/todex/schema_test.exs
git commit -m "feat: add todex database schemas"
```

If git is unavailable, note: `Checkpoint: database schemas complete`.

---

### Task 3: Accounts Context With Registration, Login, JWT, And Logout

**Files:**
- Create: `lib/todex/accounts.ex`
- Test: `test/todex/accounts_test.exs`

- [ ] **Step 1: Write failing accounts tests**

Create `test/todex/accounts_test.exs`:

```elixir
defmodule Todex.AccountsTest do
  use Todex.DataCase, async: true

  alias Todex.Accounts
  alias Todex.Todos

  @valid_attrs %{"email" => "user@example.com", "password" => "correct horse battery staple"}

  test "register_user creates user, token, and default lists" do
    assert {:ok, %{user: user, token: token}} = Accounts.register_user(@valid_attrs)
    assert user.email == "user@example.com"
    assert is_binary(token)

    lists = Todos.list_lists(user)
    assert Enum.map(lists, & &1.name) == ["Personal", "Work", "Fitness", "Groceries"]
  end

  test "login_user returns a token for valid credentials" do
    assert {:ok, %{user: user}} = Accounts.register_user(@valid_attrs)
    assert {:ok, %{user: ^user, token: token}} = Accounts.login_user("user@example.com", "correct horse battery staple")
    assert {:ok, ^user} = Accounts.verify_token(token)
  end

  test "login_user rejects invalid password" do
    assert {:ok, _} = Accounts.register_user(@valid_attrs)
    assert {:error, :invalid_credentials} = Accounts.login_user("user@example.com", "wrong password")
  end

  test "logout_token revokes a token" do
    assert {:ok, %{token: token}} = Accounts.register_user(@valid_attrs)
    assert :ok = Accounts.logout_token(token)
    assert {:error, :invalid_token} = Accounts.verify_token(token)
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run: `unbuffer mix test test/todex/accounts_test.exs`

Expected: FAIL because `Todex.Accounts` and `Todex.Todos.list_lists/1` do not exist.

- [ ] **Step 3: Implement accounts context**

Create `lib/todex/accounts.ex`:

```elixir
defmodule Todex.Accounts do
  import Ecto.Query

  alias Ecto.Multi
  alias Todex.Accounts.{AuthToken, User}
  alias Todex.Repo
  alias Todex.Todos

  def register_user(attrs) do
    Multi.new()
    |> Multi.insert(:user, User.registration_changeset(%User{}, attrs))
    |> Multi.run(:lists, fn _repo, %{user: user} -> {:ok, Todos.seed_default_lists(user)} end)
    |> Multi.run(:token, fn _repo, %{user: user} -> issue_token(user) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, token: token}} -> {:ok, %{user: user, token: token}}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  def login_user(email, password) when is_binary(email) and is_binary(password) do
    normalized_email = email |> String.trim() |> String.downcase()

    case Repo.get_by(User, email: normalized_email) do
      %User{} = user -> verify_password(user, password)
      nil -> Bcrypt.no_user_verify(); {:error, :invalid_credentials}
    end
  end

  def verify_token(token) when is_binary(token) do
    with {:ok, claims} <- verify_jwt(token),
         {:ok, token_record} <- fetch_token(claims["jti"]),
         false <- DateTime.compare(token_record.expires_at, DateTime.utc_now()) == :lt,
         %User{} = user <- Repo.get(User, token_record.user_id) do
      {:ok, user}
    else
      _ -> {:error, :invalid_token}
    end
  end

  def logout_token(token) when is_binary(token) do
    with {:ok, claims} <- verify_jwt(token),
         {:ok, token_record} <- fetch_token(claims["jti"]) do
      Repo.delete!(token_record)
      :ok
    else
      _ -> :ok
    end
  end

  defp verify_password(%User{} = user, password) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      with {:ok, token} <- issue_token(user), do: {:ok, %{user: user, token: token}}
    else
      {:error, :invalid_credentials}
    end
  end

  defp issue_token(%User{} = user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    jti = Ecto.UUID.generate()
    expires_at = DateTime.add(now, jwt_config()[:ttl_seconds], :second)

    claims = %{
      "iss" => jwt_config()[:issuer],
      "aud" => jwt_config()[:audience],
      "sub" => user.id,
      "jti" => jti,
      "iat" => DateTime.to_unix(now),
      "exp" => DateTime.to_unix(expires_at)
    }

    signer = Joken.Signer.create("HS256", jwt_config()[:secret])

    with {:ok, token, _claims} <- Joken.encode_and_sign(claims, signer),
         {:ok, _record} <-
           %AuthToken{}
           |> AuthToken.changeset(%{user_id: user.id, token_hash: hash_jti(jti), expires_at: expires_at})
           |> Repo.insert() do
      {:ok, token}
    end
  end

  defp verify_jwt(token) do
    signer = Joken.Signer.create("HS256", jwt_config()[:secret])
    Joken.verify(token, signer)
  end

  defp fetch_token(jti) when is_binary(jti) do
    case Repo.one(from token in AuthToken, where: token.token_hash == ^hash_jti(jti)) do
      %AuthToken{} = token -> {:ok, token}
      nil -> {:error, :not_found}
    end
  end

  defp hash_jti(jti), do: :crypto.hash(:sha256, jti) |> Base.encode16(case: :lower)
  defp jwt_config, do: Application.fetch_env!(:todex, :jwt)
end
```

- [ ] **Step 4: Add temporary Todos seed/list functions**

Create `lib/todex/todos.ex` if it does not exist:

```elixir
defmodule Todex.Todos do
  import Ecto.Query

  alias Todex.Accounts.User
  alias Todex.Repo
  alias Todex.Todos.List

  @default_lists [
    %{name: "Personal", icon: "home", color: "blue", position: 0, is_default: true},
    %{name: "Work", icon: "briefcase", color: "gray", position: 1, is_default: true},
    %{name: "Fitness", icon: "runner", color: "green", position: 2, is_default: true},
    %{name: "Groceries", icon: "cart", color: "orange", position: 3, is_default: true}
  ]

  def seed_default_lists(%User{} = user) do
    Enum.map(@default_lists, fn attrs ->
      attrs
      |> Map.put(:user_id, user.id)
      |> then(&List.changeset(%List{}, &1))
      |> Repo.insert!()
    end)
  end

  def list_lists(%User{} = user) do
    List
    |> where([list], list.user_id == ^user.id)
    |> order_by([list], asc: list.position, asc: list.inserted_at)
    |> Repo.all()
  end
end
```

- [ ] **Step 5: Run accounts tests**

Run: `unbuffer mix test test/todex/accounts_test.exs`

Expected: PASS.

- [ ] **Step 6: Checkpoint**

If git is initialized, run:

```bash
git add lib/todex/accounts.ex lib/todex/todos.ex test/todex/accounts_test.exs
git commit -m "feat: add account registration and jwt auth"
```

If git is unavailable, note: `Checkpoint: accounts context complete`.

---

### Task 4: Todos Context For Lists, Tasks, Filters, And Ownership

**Files:**
- Modify: `lib/todex/todos.ex`
- Test: `test/todex/todos_test.exs`

- [ ] **Step 1: Write failing todos tests**

Create `test/todex/todos_test.exs`:

```elixir
defmodule Todex.TodosTest do
  use Todex.DataCase, async: true

  alias Todex.Accounts
  alias Todex.Todos

  defp user_fixture(email \\ "owner@example.com") do
    {:ok, %{user: user}} = Accounts.register_user(%{"email" => email, "password" => "correct horse battery staple"})
    user
  end

  test "create_list creates a custom list for a user" do
    user = user_fixture()
    assert {:ok, list} = Todos.create_list(user, %{"name" => "Errands", "icon" => "cart"})
    assert list.name == "Errands"
    assert list.user_id == user.id
  end

  test "create_task rejects a list from another user" do
    owner = user_fixture("owner@example.com")
    other = user_fixture("other@example.com")
    [other_list | _] = Todos.list_lists(other)

    assert {:error, :list_not_found} = Todos.create_task(owner, %{"list_id" => other_list.id, "title" => "Steal list"})
  end

  test "list_tasks filters today upcoming completed and search" do
    user = user_fixture()
    [list | _] = Todos.list_lists(user)
    today = Date.utc_today()
    tomorrow = Date.add(today, 1)

    {:ok, _} = Todos.create_task(user, %{"list_id" => list.id, "title" => "Team standup", "due_date" => Date.to_iso8601(today)})
    {:ok, task} = Todos.create_task(user, %{"list_id" => list.id, "title" => "Book flight", "due_date" => Date.to_iso8601(tomorrow)})
    {:ok, _} = Todos.complete_task(user, task.id)

    assert [%{title: "Team standup"}] = Todos.list_tasks(user, %{"view" => "today"})
    assert [] = Todos.list_tasks(user, %{"view" => "upcoming"})
    assert [%{title: "Book flight"}] = Todos.list_tasks(user, %{"view" => "completed"})
    assert [%{title: "Team standup"}] = Todos.list_tasks(user, %{"q" => "stand"})
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run: `unbuffer mix test test/todex/todos_test.exs`

Expected: FAIL because most Todos functions are missing.

- [ ] **Step 3: Implement Todos context**

Replace `lib/todex/todos.ex` with a complete context:

```elixir
defmodule Todex.Todos do
  import Ecto.Query

  alias Todex.Accounts.User
  alias Todex.Repo
  alias Todex.Todos.{List, Task}

  @default_lists [
    %{name: "Personal", icon: "home", color: "blue", position: 0, is_default: true},
    %{name: "Work", icon: "briefcase", color: "gray", position: 1, is_default: true},
    %{name: "Fitness", icon: "runner", color: "green", position: 2, is_default: true},
    %{name: "Groceries", icon: "cart", color: "orange", position: 3, is_default: true}
  ]

  def seed_default_lists(%User{} = user) do
    Enum.map(@default_lists, fn attrs ->
      attrs |> Map.put(:user_id, user.id) |> then(&List.changeset(%List{}, &1)) |> Repo.insert!()
    end)
  end

  def list_lists(%User{} = user) do
    List |> where([list], list.user_id == ^user.id) |> order_by([list], asc: list.position, asc: list.inserted_at) |> Repo.all()
  end

  def create_list(%User{} = user, attrs) do
    attrs = attrs |> normalize_attrs() |> Map.put("user_id", user.id)
    %List{} |> List.changeset(attrs) |> Repo.insert()
  end

  def update_list(%User{} = user, id, attrs) do
    with {:ok, list} <- get_user_list(user, id) do
      list |> List.changeset(normalize_attrs(attrs)) |> Repo.update()
    end
  end

  def delete_list(%User{} = user, id) do
    with {:ok, list} <- get_user_list(user, id),
         0 <- Repo.aggregate(from(task in Task, where: task.list_id == ^list.id), :count) do
      Repo.delete(list)
    else
      {:error, reason} -> {:error, reason}
      count when is_integer(count) and count > 0 -> {:error, :list_has_tasks}
    end
  end

  def list_tasks(%User{} = user, params \\ %{}) do
    Task
    |> where([task], task.user_id == ^user.id)
    |> apply_view(params["view"])
    |> apply_list(params["list_id"])
    |> apply_status(params["status"])
    |> apply_search(params["q"])
    |> apply_due_after(params["due_after"])
    |> apply_due_before(params["due_before"])
    |> order_by([task], asc: task.due_date, asc: task.position, asc: task.inserted_at)
    |> Repo.all()
  end

  def get_task(%User{} = user, id) do
    case Repo.get_by(Task, id: id, user_id: user.id) do
      %Task{} = task -> {:ok, task}
      nil -> {:error, :not_found}
    end
  end

  def create_task(%User{} = user, attrs) do
    attrs = normalize_attrs(attrs)

    with {:ok, list} <- get_user_list(user, attrs["list_id"]) do
      attrs
      |> Map.put("user_id", user.id)
      |> Map.put("list_id", list.id)
      |> normalize_task_dates()
      |> then(&Task.changeset(%Task{}, &1))
      |> Repo.insert()
    else
      {:error, :not_found} -> {:error, :list_not_found}
    end
  end

  def update_task(%User{} = user, id, attrs) do
    attrs = normalize_attrs(attrs)

    with {:ok, task} <- get_task(user, id),
         {:ok, attrs} <- validate_task_list(user, attrs) do
      task |> Task.changeset(normalize_task_dates(attrs)) |> Repo.update()
    end
  end

  def delete_task(%User{} = user, id) do
    with {:ok, task} <- get_task(user, id), do: Repo.delete(task)
  end

  def complete_task(%User{} = user, id) do
    update_task(user, id, %{"status" => "completed", "completed_at" => DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  def reopen_task(%User{} = user, id) do
    update_task(user, id, %{"status" => "active", "completed_at" => nil})
  end

  defp get_user_list(%User{} = user, id) when is_binary(id) do
    case Repo.get_by(List, id: id, user_id: user.id) do
      %List{} = list -> {:ok, list}
      nil -> {:error, :not_found}
    end
  end

  defp get_user_list(_user, _id), do: {:error, :not_found}

  defp validate_task_list(user, %{"list_id" => list_id} = attrs) do
    with {:ok, list} <- get_user_list(user, list_id), do: {:ok, Map.put(attrs, "list_id", list.id)}
  end

  defp validate_task_list(_user, attrs), do: {:ok, attrs}

  defp normalize_attrs(attrs) when is_map(attrs), do: Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

  defp normalize_task_dates(attrs) do
    attrs
    |> normalize_date("due_date")
    |> normalize_datetime("completed_at")
  end

  defp normalize_date(attrs, key) do
    case attrs[key] do
      value when is_binary(value) -> Map.put(attrs, key, Date.from_iso8601!(value))
      _ -> attrs
    end
  end

  defp normalize_datetime(attrs, key) do
    case attrs[key] do
      %DateTime{} -> attrs
      value when is_binary(value) -> Map.put(attrs, key, DateTime.from_iso8601(value) |> elem(1))
      _ -> attrs
    end
  end

  defp apply_view(query, "today"), do: where(query, [task], task.status == :active and task.due_date == ^Date.utc_today())
  defp apply_view(query, "upcoming"), do: where(query, [task], task.status == :active and task.due_date > ^Date.utc_today())
  defp apply_view(query, "completed"), do: where(query, [task], task.status == :completed)
  defp apply_view(query, _), do: query

  defp apply_list(query, list_id) when is_binary(list_id), do: where(query, [task], task.list_id == ^list_id)
  defp apply_list(query, _), do: query

  defp apply_status(query, status) when status in ["active", "completed"], do: where(query, [task], task.status == ^String.to_existing_atom(status))
  defp apply_status(query, _), do: query

  defp apply_search(query, q) when is_binary(q) and byte_size(q) > 0 do
    pattern = "%#{q}%"
    where(query, [task], ilike(task.title, ^pattern) or ilike(task.notes, ^pattern))
  end

  defp apply_search(query, _), do: query
  defp apply_due_after(query, value) when is_binary(value), do: where(query, [task], task.due_date >= ^Date.from_iso8601!(value))
  defp apply_due_after(query, _), do: query
  defp apply_due_before(query, value) when is_binary(value), do: where(query, [task], task.due_date <= ^Date.from_iso8601!(value))
  defp apply_due_before(query, _), do: query
end
```

- [ ] **Step 4: Run todos tests**

Run: `unbuffer mix test test/todex/todos_test.exs`

Expected: PASS.

- [ ] **Step 5: Checkpoint**

If git is initialized, run:

```bash
git add lib/todex/todos.ex test/todex/todos_test.exs
git commit -m "feat: add todos context"
```

If git is unavailable, note: `Checkpoint: todos context complete`.

---

### Task 5: REST JSON Boundary, Auth Plug, And Error Rendering

**Files:**
- Create: `lib/todex_web/json.ex`
- Create: `lib/todex_web/errors.ex`
- Create: `lib/todex_web/auth_plug.ex`
- Modify: `lib/todex_web/router.ex`
- Test: `test/todex_web/rest_api_test.exs`

- [ ] **Step 1: Write failing REST API tests**

Create `test/todex_web/rest_api_test.exs`:

```elixir
defmodule TodexWeb.RestApiTest do
  use Todex.DataCase, async: true
  use Plug.Test

  @opts TodexWeb.Router.init([])

  test "register, create task, list today tasks, and complete task" do
    register_conn = post_json("/api/auth/register", %{email: "api@example.com", password: "correct horse battery staple"})
    assert register_conn.status == 201
    %{"token" => token, "user" => %{"email" => "api@example.com"}} = Jason.decode!(register_conn.resp_body)

    lists_conn = auth_conn(:get, "/api/lists", token) |> TodexWeb.Router.call(@opts)
    assert lists_conn.status == 200
    [%{"id" => list_id} | _] = Jason.decode!(lists_conn.resp_body)["data"]

    task_conn = post_json("/api/tasks", %{title: "Team standup", list_id: list_id, due_date: Date.to_iso8601(Date.utc_today())}, token)
    assert task_conn.status == 201
    %{"data" => %{"id" => task_id}} = Jason.decode!(task_conn.resp_body)

    today_conn = auth_conn(:get, "/api/tasks?view=today", token) |> TodexWeb.Router.call(@opts)
    assert [%{"title" => "Team standup"}] = Jason.decode!(today_conn.resp_body)["data"]

    complete_conn = post_json("/api/tasks/#{task_id}/complete", %{}, token)
    assert complete_conn.status == 200
    assert Jason.decode!(complete_conn.resp_body)["data"]["status"] == "completed"
  end

  test "protected endpoints reject missing token" do
    conn = conn(:get, "/api/tasks") |> TodexWeb.Router.call(@opts)
    assert conn.status == 401
    assert Jason.decode!(conn.resp_body)["error"]["code"] == "unauthorized"
  end

  defp post_json(path, body, token \\ nil) do
    conn = conn(:post, path, Jason.encode!(body)) |> put_req_header("content-type", "application/json")
    conn = if token, do: put_req_header(conn, "authorization", "Bearer #{token}"), else: conn
    TodexWeb.Router.call(conn, @opts)
  end

  defp auth_conn(method, path, token) do
    conn(method, path) |> put_req_header("authorization", "Bearer #{token}")
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run: `unbuffer mix test test/todex_web/rest_api_test.exs`

Expected: FAIL because JSON boundary modules/routes are missing.

- [ ] **Step 3: Implement JSON and error helpers**

Create `lib/todex_web/json.ex`:

```elixir
defmodule TodexWeb.Json do
  def user(user), do: %{id: user.id, email: user.email}

  def list(list), do: %{id: list.id, name: list.name, icon: list.icon, color: list.color, position: list.position, is_default: list.is_default}

  def task(task) do
    %{
      id: task.id,
      list_id: task.list_id,
      title: task.title,
      notes: task.notes,
      status: to_string(task.status),
      due_date: encode_date(task.due_date),
      completed_at: encode_datetime(task.completed_at),
      position: task.position
    }
  end

  defp encode_date(nil), do: nil
  defp encode_date(date), do: Date.to_iso8601(date)
  defp encode_datetime(nil), do: nil
  defp encode_datetime(datetime), do: DateTime.to_iso8601(datetime)
end
```

Create `lib/todex_web/errors.ex`:

```elixir
defmodule TodexWeb.Errors do
  import Plug.Conn

  def send_error(conn, status, code, message, details \\ %{}) do
    body = Jason.encode!(%{error: %{code: code, message: message, details: details}})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
    |> halt()
  end

  def changeset_details(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  def render_result(conn, {:ok, data}, status, mapper), do: json(conn, status, %{data: mapper.(data)})
  def render_result(conn, {:error, %Ecto.Changeset{} = changeset}, _status, _mapper), do: send_error(conn, 422, "validation_failed", "Validation failed", changeset_details(changeset))
  def render_result(conn, {:error, :not_found}, _status, _mapper), do: send_error(conn, 404, "not_found", "Resource not found")
  def render_result(conn, {:error, :list_not_found}, _status, _mapper), do: send_error(conn, 422, "list_not_found", "List not found")
  def render_result(conn, {:error, :list_has_tasks}, _status, _mapper), do: send_error(conn, 422, "list_has_tasks", "List has tasks")

  def json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
    |> halt()
  end
end
```

Create `lib/todex_web/auth_plug.ex`:

```elixir
defmodule TodexWeb.AuthPlug do
  import Plug.Conn

  alias Todex.Accounts
  alias TodexWeb.Errors

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Accounts.verify_token(token) do
      assign(conn, :current_user, user)
    else
      _ -> Errors.send_error(conn, 401, "unauthorized", "Missing or invalid bearer token")
    end
  end
end
```

- [ ] **Step 4: Implement REST routes**

Replace `lib/todex_web/router.ex` with REST routes and keep `unmatched/1` last:

```elixir
defmodule TodexWeb.Router do
  use Francis

  alias Todex.{Accounts, Todos}
  alias TodexWeb.{AuthPlug, Errors, Json}

  post("/api/auth/register", fn conn ->
    case Accounts.register_user(conn.body_params) do
      {:ok, %{user: user, token: token}} -> Errors.json(conn, 201, %{user: Json.user(user), token: token})
      {:error, %Ecto.Changeset{} = changeset} -> Errors.send_error(conn, 422, "validation_failed", "Validation failed", Errors.changeset_details(changeset))
    end
  end)

  post("/api/auth/login", fn conn ->
    case Accounts.login_user(conn.body_params["email"], conn.body_params["password"]) do
      {:ok, %{user: user, token: token}} -> Errors.json(conn, 200, %{user: Json.user(user), token: token})
      {:error, :invalid_credentials} -> Errors.send_error(conn, 401, "invalid_credentials", "Invalid email or password")
    end
  end)

  plug(AuthPlug)

  post("/api/auth/logout", fn conn ->
    ["Bearer " <> token] = Plug.Conn.get_req_header(conn, "authorization")
    :ok = Accounts.logout_token(token)
    Errors.json(conn, 200, %{data: %{ok: true}})
  end)

  get("/api/me", fn conn -> Errors.json(conn, 200, %{data: Json.user(conn.assigns.current_user)}) end)
  get("/api/lists", fn conn -> Errors.json(conn, 200, %{data: Enum.map(Todos.list_lists(conn.assigns.current_user), &Json.list/1)}) end)
  post("/api/lists", fn conn -> Errors.render_result(conn, Todos.create_list(conn.assigns.current_user, conn.body_params), 201, &Json.list/1) end)
  patch("/api/lists/:id", fn conn -> Errors.render_result(conn, Todos.update_list(conn.assigns.current_user, conn.params["id"], conn.body_params), 200, &Json.list/1) end)
  delete("/api/lists/:id", fn conn -> Errors.render_result(conn, Todos.delete_list(conn.assigns.current_user, conn.params["id"]), 200, &Json.list/1) end)

  get("/api/tasks", fn conn -> Errors.json(conn, 200, %{data: Enum.map(Todos.list_tasks(conn.assigns.current_user, conn.params), &Json.task/1)}) end)
  post("/api/tasks", fn conn -> Errors.render_result(conn, Todos.create_task(conn.assigns.current_user, conn.body_params), 201, &Json.task/1) end)
  get("/api/tasks/:id", fn conn -> Errors.render_result(conn, Todos.get_task(conn.assigns.current_user, conn.params["id"]), 200, &Json.task/1) end)
  patch("/api/tasks/:id", fn conn -> Errors.render_result(conn, Todos.update_task(conn.assigns.current_user, conn.params["id"], conn.body_params), 200, &Json.task/1) end)
  delete("/api/tasks/:id", fn conn -> Errors.render_result(conn, Todos.delete_task(conn.assigns.current_user, conn.params["id"]), 200, &Json.task/1) end)
  post("/api/tasks/:id/complete", fn conn -> Errors.render_result(conn, Todos.complete_task(conn.assigns.current_user, conn.params["id"]), 200, &Json.task/1) end)
  post("/api/tasks/:id/reopen", fn conn -> Errors.render_result(conn, Todos.reopen_task(conn.assigns.current_user, conn.params["id"]), 200, &Json.task/1) end)

  unmatched(fn conn -> Errors.send_error(conn, 404, "not_found", "Not found") end)
end
```

- [ ] **Step 5: Run REST tests**

Run: `unbuffer mix test test/todex_web/rest_api_test.exs`

Expected: PASS.

- [ ] **Step 6: Checkpoint**

If git is initialized, run:

```bash
git add lib/todex_web test/todex_web/rest_api_test.exs
git commit -m "feat: add authenticated rest api"
```

If git is unavailable, note: `Checkpoint: REST API complete`.

---

### Task 6: OpenAPI Spec And Dev Swagger UI

**Files:**
- Create: `lib/todex_web/schemas.ex`
- Create: `lib/todex_web/api_spec.ex`
- Modify: `lib/todex_web/router.ex`
- Test: `test/todex_web/openapi_test.exs`

- [ ] **Step 1: Write failing OpenAPI tests**

Create `test/todex_web/openapi_test.exs`:

```elixir
defmodule TodexWeb.OpenApiTest do
  use Todex.DataCase, async: true
  use Plug.Test

  @opts TodexWeb.Router.init([])

  test "openapi endpoint renders spec with expected paths and bearer security" do
    conn = conn(:get, "/api/openapi") |> TodexWeb.Router.call(@opts)

    assert conn.status == 200
    spec = Jason.decode!(conn.resp_body)
    assert spec["paths"]["/api/tasks"]
    assert spec["paths"]["/api/auth/login"]
    assert spec["components"]["securitySchemes"]["bearerAuth"]["scheme"] == "bearer"
  end
end
```

- [ ] **Step 2: Run test to verify failure**

Run: `unbuffer mix test test/todex_web/openapi_test.exs`

Expected: FAIL because `/api/openapi` is protected or missing.

- [ ] **Step 3: Add schemas and manual API spec**

Create `lib/todex_web/schemas.ex` with schema modules for `User`, `List`, `Task`, `AuthResponse`, `ErrorResponse`, `RegisterRequest`, `LoginRequest`, `ListRequest`, and `TaskRequest`. Use this pattern for each:

```elixir
defmodule TodexWeb.Schemas do
  alias OpenApiSpex.Schema

  defmodule User do
    require OpenApiSpex
    OpenApiSpex.schema(%{title: "User", type: :object, properties: %{id: %Schema{type: :string, format: :uuid}, email: %Schema{type: :string, format: :email}}, required: [:id, :email]})
  end

  defmodule List do
    require OpenApiSpex
    OpenApiSpex.schema(%{title: "List", type: :object, properties: %{id: %Schema{type: :string, format: :uuid}, name: %Schema{type: :string}, icon: %Schema{type: :string, nullable: true}, color: %Schema{type: :string, nullable: true}, position: %Schema{type: :integer}, is_default: %Schema{type: :boolean}}, required: [:id, :name, :position, :is_default]})
  end

  defmodule Task do
    require OpenApiSpex
    OpenApiSpex.schema(%{title: "Task", type: :object, properties: %{id: %Schema{type: :string, format: :uuid}, list_id: %Schema{type: :string, format: :uuid}, title: %Schema{type: :string}, notes: %Schema{type: :string, nullable: true}, status: %Schema{type: :string, enum: ["active", "completed"]}, due_date: %Schema{type: :string, format: :date, nullable: true}, completed_at: %Schema{type: :string, format: :"date-time", nullable: true}, position: %Schema{type: :integer}}, required: [:id, :list_id, :title, :status, :position]})
  end

  defmodule ErrorResponse do
    require OpenApiSpex
    OpenApiSpex.schema(%{title: "ErrorResponse", type: :object, properties: %{error: %Schema{type: :object, properties: %{code: %Schema{type: :string}, message: %Schema{type: :string}, details: %Schema{type: :object}}}}, required: [:error]})
  end
end
```

Create `lib/todex_web/api_spec.ex`:

```elixir
defmodule TodexWeb.ApiSpec do
  alias OpenApiSpex.{Components, Info, OpenApi, Operation, PathItem, Paths, Response, Schema, SecurityScheme, Server}

  @behaviour OpenApiSpex.OpenApi

  @impl true
  def spec do
    %OpenApi{
      info: %Info{title: "Todex API", version: "0.1.0"},
      servers: [%Server{url: "/"}],
      components: %Components{securitySchemes: %{"bearerAuth" => %SecurityScheme{type: "http", scheme: "bearer", bearerFormat: "JWT"}}},
      paths: paths()
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp paths do
    %Paths{
      "/api/auth/register" => %PathItem{post: operation("registerUser", "Register user", false)},
      "/api/auth/login" => %PathItem{post: operation("loginUser", "Login user", false)},
      "/api/auth/logout" => %PathItem{post: operation("logoutUser", "Logout user", true)},
      "/api/me" => %PathItem{get: operation("getMe", "Get current user", true)},
      "/api/lists" => %PathItem{get: operation("listLists", "List lists", true), post: operation("createList", "Create list", true)},
      "/api/lists/{id}" => %PathItem{patch: operation("updateList", "Update list", true), delete: operation("deleteList", "Delete list", true)},
      "/api/tasks" => %PathItem{get: operation("listTasks", "List tasks", true), post: operation("createTask", "Create task", true)},
      "/api/tasks/{id}" => %PathItem{get: operation("getTask", "Get task", true), patch: operation("updateTask", "Update task", true), delete: operation("deleteTask", "Delete task", true)},
      "/api/tasks/{id}/complete" => %PathItem{post: operation("completeTask", "Complete task", true)},
      "/api/tasks/{id}/reopen" => %PathItem{post: operation("reopenTask", "Reopen task", true)}
    }
  end

  defp operation(operation_id, summary, secured?) do
    %Operation{
      operationId: operation_id,
      summary: summary,
      security: if(secured?, do: [%{"bearerAuth" => []}], else: []),
      responses: %{200 => %Response{description: "Success", content: %{"application/json" => %OpenApiSpex.MediaType{schema: %Schema{type: :object}}}}, 401 => %Response{description: "Unauthorized"}, 422 => %Response{description: "Validation failed"}}
    }
  end
end
```

- [ ] **Step 4: Mount OpenAPI routes before auth plug**

In `lib/todex_web/router.ex`, add before `plug(AuthPlug)`:

```elixir
plug(OpenApiSpex.Plug.PutApiSpec, module: TodexWeb.ApiSpec)

get("/api/openapi", fn conn ->
  OpenApiSpex.Plug.RenderSpec.call(conn, OpenApiSpex.Plug.RenderSpec.init([]))
end)

get("/swaggerui", fn conn ->
  if Mix.env() == :dev do
    OpenApiSpex.Plug.SwaggerUI.call(conn, OpenApiSpex.Plug.SwaggerUI.init(path: "/api/openapi"))
  else
    TodexWeb.Errors.send_error(conn, 404, "not_found", "Not found")
  end
end)
```

- [ ] **Step 5: Run OpenAPI tests**

Run: `unbuffer mix test test/todex_web/openapi_test.exs`

Expected: PASS.

- [ ] **Step 6: Checkpoint**

If git is initialized, run:

```bash
git add lib/todex_web/schemas.ex lib/todex_web/api_spec.ex lib/todex_web/router.ex test/todex_web/openapi_test.exs
git commit -m "feat: serve openapi spec"
```

If git is unavailable, note: `Checkpoint: OpenAPI complete`.

---

### Task 7: Realtime Registry And WebSocket Command Handler

**Files:**
- Modify: `lib/todex/realtime.ex`
- Create: `lib/todex_web/realtime/command_handler.ex`
- Modify: `lib/todex_web/router.ex`
- Test: `test/todex_web/realtime_command_handler_test.exs`

- [ ] **Step 1: Write failing command handler tests**

Create `test/todex_web/realtime_command_handler_test.exs`:

```elixir
defmodule TodexWeb.Realtime.CommandHandlerTest do
  use Todex.DataCase, async: true

  alias Todex.Accounts
  alias Todex.Todos
  alias TodexWeb.Realtime.CommandHandler

  test "task:create command creates task and returns ok envelope" do
    {:ok, %{user: user}} = Accounts.register_user(%{"email" => "ws@example.com", "password" => "correct horse battery staple"})
    [list | _] = Todos.list_lists(user)

    command = %{"id" => "1", "type" => "task:create", "payload" => %{"list_id" => list.id, "title" => "Socket task"}}

    assert {:ok, response, broadcast} = CommandHandler.handle(user, command)
    assert response.id == "1"
    assert response.type == "ok"
    assert broadcast.type == "task:created"
    assert broadcast.payload.title == "Socket task"
  end

  test "unknown command returns error envelope" do
    {:ok, %{user: user}} = Accounts.register_user(%{"email" => "badws@example.com", "password" => "correct horse battery staple"})

    assert {:error, response} = CommandHandler.handle(user, %{"id" => "2", "type" => "nope", "payload" => %{}})
    assert response.type == "error"
    assert response.error.code == "unknown_command"
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run: `unbuffer mix test test/todex_web/realtime_command_handler_test.exs`

Expected: FAIL because command handler does not exist.

- [ ] **Step 3: Implement realtime registry**

Replace `lib/todex/realtime.ex`:

```elixir
defmodule Todex.Realtime do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def register(user_id, transport), do: GenServer.call(__MODULE__, {:register, user_id, transport})
  def unregister(user_id, transport), do: GenServer.cast(__MODULE__, {:unregister, user_id, transport})
  def broadcast(user_id, event), do: GenServer.cast(__MODULE__, {:broadcast, user_id, event})

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:register, user_id, transport}, _from, state) do
    transports = state |> Map.get(user_id, MapSet.new()) |> MapSet.put(transport)
    {:reply, :ok, Map.put(state, user_id, transports)}
  end

  @impl true
  def handle_cast({:unregister, user_id, transport}, state) do
    transports = state |> Map.get(user_id, MapSet.new()) |> MapSet.delete(transport)
    {:noreply, Map.put(state, user_id, transports)}
  end

  @impl true
  def handle_cast({:broadcast, user_id, event}, state) do
    payload = Jason.encode!(event)
    state |> Map.get(user_id, MapSet.new()) |> Enum.each(&send(&1, payload))
    {:noreply, state}
  end
end
```

- [ ] **Step 4: Implement command handler**

Create `lib/todex_web/realtime/command_handler.ex`:

```elixir
defmodule TodexWeb.Realtime.CommandHandler do
  alias Todex.Todos
  alias TodexWeb.Json

  def handle(user, %{"id" => id, "type" => type, "payload" => payload}) when is_map(payload) do
    dispatch(user, id, type, payload)
  end

  def handle(_user, _command), do: {:error, error(nil, "invalid_command", "Invalid command envelope")}

  defp dispatch(user, id, "task:create", payload), do: mutation(id, "task:created", Todos.create_task(user, payload), &Json.task/1)
  defp dispatch(user, id, "task:update", %{"id" => task_id} = payload), do: mutation(id, "task:updated", Todos.update_task(user, task_id, Map.delete(payload, "id")), &Json.task/1)
  defp dispatch(user, id, "task:delete", %{"id" => task_id}), do: mutation(id, "task:deleted", Todos.delete_task(user, task_id), &Json.task/1)
  defp dispatch(user, id, "task:complete", %{"id" => task_id}), do: mutation(id, "task:updated", Todos.complete_task(user, task_id), &Json.task/1)
  defp dispatch(user, id, "task:reopen", %{"id" => task_id}), do: mutation(id, "task:updated", Todos.reopen_task(user, task_id), &Json.task/1)
  defp dispatch(user, id, "list:create", payload), do: mutation(id, "list:created", Todos.create_list(user, payload), &Json.list/1)
  defp dispatch(user, id, "list:update", %{"id" => list_id} = payload), do: mutation(id, "list:updated", Todos.update_list(user, list_id, Map.delete(payload, "id")), &Json.list/1)
  defp dispatch(user, id, "list:delete", %{"id" => list_id}), do: mutation(id, "list:deleted", Todos.delete_list(user, list_id), &Json.list/1)
  defp dispatch(_user, id, _type, _payload), do: {:error, error(id, "unknown_command", "Unknown command")}

  defp mutation(id, event_type, {:ok, record}, mapper) do
    payload = mapper.(record)
    {:ok, %{id: id, type: "ok", payload: payload}, %{type: event_type, payload: payload}}
  end

  defp mutation(id, _event_type, {:error, reason}, _mapper), do: {:error, error(id, to_string(reason), "Command failed")}

  defp error(id, code, message), do: %{id: id, type: "error", error: %{code: code, message: message, details: %{}}}
end
```

- [ ] **Step 5: Add WebSocket route**

In `lib/todex_web/router.ex`, add before `unmatched/1`:

```elixir
ws("/api/ws", fn
  :join, socket ->
    with token when is_binary(token) <- socket.params["token"],
         {:ok, user} <- Todex.Accounts.verify_token(token) do
      :ok = Todex.Realtime.register(user.id, socket.transport)
      {:reply, %{type: "connected", payload: %{user_id: user.id}}}
    else
      _ -> {:reply, %{type: "error", error: %{code: "unauthorized", message: "Invalid token", details: %{}}}}
    end

  {:received, message}, socket ->
    with {:ok, command} <- Jason.decode(message),
         {:ok, user} <- Todex.Accounts.verify_token(socket.params["token"]),
         {:ok, response, broadcast} <- TodexWeb.Realtime.CommandHandler.handle(user, command) do
      Todex.Realtime.broadcast(user.id, broadcast)
      {:reply, response}
    else
      {:error, response} when is_map(response) -> {:reply, response}
      _ -> {:reply, %{type: "error", error: %{code: "invalid_command", message: "Invalid command", details: %{}}}}
    end

  {:close, _reason}, socket ->
    with {:ok, user} <- Todex.Accounts.verify_token(socket.params["token"]) do
      Todex.Realtime.unregister(user.id, socket.transport)
    end

    :ok
end)
```

- [ ] **Step 6: Run realtime tests**

Run: `unbuffer mix test test/todex_web/realtime_command_handler_test.exs`

Expected: PASS.

- [ ] **Step 7: Checkpoint**

If git is initialized, run:

```bash
git add lib/todex/realtime.ex lib/todex_web/router.ex lib/todex_web/realtime test/todex_web/realtime_command_handler_test.exs
git commit -m "feat: add websocket command api"
```

If git is unavailable, note: `Checkpoint: realtime API complete`.

---

### Task 8: Final Verification And Documentation

**Files:**
- Create: `docs/api/websocket-protocol.md`
- Modify: `README.md` if present, otherwise create it.

- [ ] **Step 1: Document WebSocket protocol**

Create `docs/api/websocket-protocol.md`:

```markdown
# Todex WebSocket Protocol

Endpoint: `GET /api/ws?token=<jwt>`

Commands use this envelope:

```json
{"id":"client-command-id","type":"task:create","payload":{}}
```

Successful responses use:

```json
{"id":"client-command-id","type":"ok","payload":{}}
```

Errors use:

```json
{"id":"client-command-id","type":"error","error":{"code":"validation_failed","message":"Command failed","details":{}}}
```

Supported commands: `list:create`, `list:update`, `list:delete`, `task:create`, `task:update`, `task:delete`, `task:complete`, `task:reopen`.

Broadcast events: `list:created`, `list:updated`, `list:deleted`, `task:created`, `task:updated`, `task:deleted`.
```

- [ ] **Step 2: Add README usage**

Create or update `README.md`:

```markdown
# Todex

Francis-based todo API with PostgreSQL, JWT auth, OpenAPI, and WebSocket realtime commands.

## Setup

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix run --no-halt
```

## API

- OpenAPI JSON: `GET /api/openapi`
- Swagger UI in dev: `GET /swaggerui`
- WebSocket: `GET /api/ws?token=<jwt>`
```

- [ ] **Step 3: Run full verification**

Run: `mix format --check-formatted`

Expected: exits 0.

Run: `unbuffer mix test`

Expected: all tests pass.

Run: `unbuffer mix compile --warnings-as-errors`

Expected: no warnings.

- [ ] **Step 4: Check generated OpenAPI task**

Run: `mix openapi.spec.json --spec TodexWeb.ApiSpec --start-app=false`

Expected: `openapi.json` is generated and includes `/api/tasks`.

- [ ] **Step 5: Final checkpoint**

If git is initialized, run:

```bash
git add README.md docs/api openapi.json
git commit -m "docs: document todex api"
```

If git is unavailable, note: `Checkpoint: final docs and verification complete`.

---

## Self-Review

Spec coverage:

- PostgreSQL/Ecto foundation covered by Tasks 1 and 2.
- Authenticated users, JWT tokens, and logout covered by Task 3.
- Default seeded lists, list CRUD, task CRUD, filters, completion, and ownership covered by Task 4.
- REST routes and error shape covered by Task 5.
- OpenAPI JSON and dev Swagger UI covered by Task 6.
- WebSocket full command API and per-user broadcasting covered by Task 7.
- WebSocket documentation and verification covered by Task 8.

Placeholder scan:

- No placeholder markers or unspecified validation steps remain.
- Each task includes exact paths, concrete commands, expected outcomes, and code for changed modules/tests.

Type consistency:

- Database field names use `is_default`, `completed_at`, `due_date`, `token_hash` consistently.
- REST and WebSocket task/list serialization share `TodexWeb.Json`.
- WebSocket command names match the approved design.
