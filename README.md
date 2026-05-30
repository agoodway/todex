# Todex

A todo and notes API built on [Francis](https://hex.pm/packages/francis) (Bandit) with
PostgreSQL, JWT authentication, an OpenAPI 3 spec, and a realtime WebSocket command
channel.

Todex manages four resources, all scoped to the authenticated user:

- **Lists** — containers for tasks (e.g. "Work", "Personal").
- **Tasks** — todo items that belong to a list, with status, due date, and notes.
- **Note folders** — containers for notes.
- **Notes** — rich text notes that belong to a folder, with pin and soft-delete support.

Every mutation is available over both a **REST API** and an authenticated **WebSocket**
command API. Successful WebSocket mutations are broadcast to all of the user's connected
clients, making realtime sync straightforward.

## Tech stack

| Concern        | Choice                                              |
| -------------- | --------------------------------------------------- |
| Web framework  | Francis on Bandit                                   |
| Database       | PostgreSQL (via Ecto), `binary_id`/UUID primary keys |
| Auth           | JWT (Joken, HS256) + Bcrypt password hashing        |
| API spec       | OpenApiSpex (OpenAPI 3)                              |
| Realtime       | WebSocket command/broadcast protocol                |

## Prerequisites

- Elixir `~> 1.18` and a compatible Erlang/OTP
- PostgreSQL running locally (or reachable via env vars)
- The `citext` and `pg_trgm` extensions are enabled automatically by migrations

## Setup

```bash
# 1. Install dependencies
mix deps.get

# 2. Create and migrate the database
mix ecto.create
mix ecto.migrate

# 3. Start the server (listens on http://localhost:6543 in dev)
mix run --no-halt
```

A quick health check confirms the server is up:

```bash
curl http://localhost:6543/
# => {"ok":true}
```

## Configuration

Configuration is read from environment variables. Sensible defaults are provided for
local development, so no setup is required to run in `dev`.

| Variable                 | Used in     | Default (dev/test)                       | Notes                                                        |
| ------------------------ | ----------- | ---------------------------------------- | ------------------------------------------------------------ |
| `TODEX_JWT_SECRET`       | all envs    | insecure dev fallback                    | **Required in prod**, and must be **≥ 32 bytes**.            |
| `TODEX_JWT_TTL_SECONDS`  | prod        | `86400` (24h)                            | Token lifetime in seconds.                                   |
| `DATABASE_URL`           | prod        | —                                        | **Required in prod.**                                        |
| `POSTGRES_USER`          | dev/test    | `postgres`                               |                                                              |
| `POSTGRES_PASSWORD`      | dev/test    | `postgres`                               |                                                              |
| `POSTGRES_HOST`          | dev/test    | `localhost`                              |                                                              |
| `POSTGRES_DB`            | dev/test    | `todex_dev` / `todex_test`               |                                                              |
| `PORT`                   | prod        | `4000`                                   | Dev is fixed at `6543`, test at `4002`.                      |
| `POOL_SIZE`              | prod        | `10`                                     | DB connection pool size.                                     |
| `ECTO_SSL`               | prod        | `true`                                   | Set to `false` to disable DB SSL.                            |

Generate a strong production secret with:

```bash
openssl rand -base64 48
```

The app **fails to boot in production** if `TODEX_JWT_SECRET` is missing or shorter than
32 bytes — a misconfiguration surfaces loudly instead of silently using a weak key.

## API conventions

**Base URL (dev):** `http://localhost:6543`

All application endpoints are mounted under `/api`. Every endpoint except
`POST /api/auth/register` and `POST /api/auth/login` requires authentication.

**Request bodies** must be JSON and sent with `Content-Type: application/json`. A request
with the wrong content type is rejected with `415 unsupported_media_type`; malformed JSON
returns `400 invalid_json`.

**Authentication** uses a bearer token:

```
Authorization: Bearer <jwt>
```

**Success responses** wrap the result in a `data` envelope:

```json
{ "data": { "task": { "id": "…", "title": "Buy milk" } } }
```

**Error responses** use a consistent `error` envelope:

```json
{ "error": { "code": "validation_failed", "message": "Validation failed", "details": { "title": ["can't be blank"] } } }
```

### Error codes

| HTTP | `code`                   | Meaning                                                       |
| ---- | ------------------------ | ------------------------------------------------------------- |
| 400  | `invalid_json`           | Request body was not valid JSON.                              |
| 401  | `unauthorized`           | Missing/invalid/expired bearer token.                         |
| 401  | `invalid_credentials`    | Login email/password did not match.                           |
| 404  | `not_found`              | Resource does not exist (or is not owned by you).             |
| 415  | `unsupported_media_type` | `Content-Type` was not `application/json`.                    |
| 422  | `validation_failed`      | Body failed validation; see `details` for field errors.       |
| 422  | `list_not_found`         | Referenced `list_id` is not owned by you.                     |
| 422  | `list_has_tasks`         | Cannot delete a list that still has tasks.                    |
| 422  | `folder_not_found`       | Referenced `folder_id` is not owned by you.                   |
| 422  | `folder_has_notes`       | Cannot delete a folder that still has active notes.           |
| 429  | `rate_limited`           | Too many auth attempts; see rate limiting below.              |

### Rate limiting

`POST /api/auth/register` and `POST /api/auth/login` are rate limited to **10 requests
per 60 seconds per client IP**. Exceeding the limit returns `429 rate_limited`.

## Authentication

### Register

Creates a user and seeds default lists (Personal, Work, Fitness, Groceries) and a default
"Notes" folder. Returns the user and a JWT. Passwords must be **8–72 characters**.

```bash
curl -X POST http://localhost:6543/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email": "ada@example.com", "password": "correct horse battery"}'
```

```json
{
  "data": {
    "user": { "id": "…", "email": "ada@example.com", "inserted_at": "…", "updated_at": "…" },
    "token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

### Log in

```bash
curl -X POST http://localhost:6543/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email": "ada@example.com", "password": "correct horse battery"}'
```

Returns the same `{ "data": { "user", "token" } }` shape. Invalid credentials return
`401 invalid_credentials`.

### Use the token

Save the token and send it on every subsequent request:

```bash
TOKEN="eyJhbGciOiJIUzI1NiIs..."

curl http://localhost:6543/api/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

```json
{ "data": { "user": { "id": "…", "email": "ada@example.com" } } }
```

### Log out

Revokes the current token server-side (it can no longer be used):

```bash
curl -X POST http://localhost:6543/api/auth/logout \
  -H "Authorization: Bearer $TOKEN"
# => {"data":{"ok":true}}
```

## REST API reference

All examples below assume `TOKEN` is set and are sent to the dev base URL. Authorization
and content-type headers are abbreviated as `-H "Authorization: Bearer $TOKEN"` and
`-H 'Content-Type: application/json'`.

### Lists

| Method & path           | Description                                  |
| ----------------------- | -------------------------------------------- |
| `GET /api/lists`        | List all of the user's lists.                |
| `POST /api/lists`       | Create a list.                               |
| `GET /api/lists/:id`    | Fetch one list.                              |
| `PATCH /api/lists/:id`  | Update a list.                               |
| `DELETE /api/lists/:id` | Delete a list (fails if it still has tasks). |

**Fields:** `name` (required, 1–80 chars), `icon`, `color`, `position` (integer).
`is_default` is read-only and ignored on writes.

```bash
# Create
curl -X POST http://localhost:6543/api/lists \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name": "Side Project", "icon": "rocket", "color": "indigo", "position": 4}'

# Update
curl -X PATCH http://localhost:6543/api/lists/$LIST_ID \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name": "Side Projects"}'

# Delete
curl -X DELETE http://localhost:6543/api/lists/$LIST_ID \
  -H "Authorization: Bearer $TOKEN"
```

A list response looks like:

```json
{
  "data": {
    "list": {
      "id": "…", "name": "Side Project", "icon": "rocket", "color": "indigo",
      "position": 4, "is_default": false, "inserted_at": "…", "updated_at": "…"
    }
  }
}
```

### Tasks

| Method & path                   | Description                                |
| ------------------------------- | ------------------------------------------ |
| `GET /api/tasks`                | List tasks (supports filters, see below).  |
| `POST /api/tasks`               | Create a task.                             |
| `GET /api/tasks/:id`            | Fetch one task.                            |
| `PATCH /api/tasks/:id`          | Update a task.                             |
| `DELETE /api/tasks/:id`         | Delete a task.                             |
| `POST /api/tasks/:id/complete`  | Mark a task completed.                     |
| `POST /api/tasks/:id/reopen`    | Mark a completed task active again.        |

**Fields:** `list_id` (required, must be a list you own), `title` (required, 1–255 chars),
`notes` (≤ 100,000 chars), `status` (`active` | `completed`), `due_date` (ISO 8601 date,
e.g. `2026-06-01`), `completed_at` (ISO 8601 datetime), `position` (integer).

**Query filters for `GET /api/tasks`:**

| Param        | Values / format                       | Effect                                         |
| ------------ | ------------------------------------- | ---------------------------------------------- |
| `view`       | `today` \| `upcoming` \| `completed`  | Convenience views (today/upcoming are active). |
| `list_id`    | UUID                                  | Only tasks in that list.                       |
| `status`     | `active` \| `completed`               | Filter by status.                              |
| `q`          | text                                  | Case-insensitive search of title and notes.    |
| `due_after`  | ISO date (`2026-06-01`)               | Tasks due on/after the date.                   |
| `due_before` | ISO date                              | Tasks due on/before the date.                  |

```bash
# Create a task
curl -X POST http://localhost:6543/api/tasks \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"list_id": "'"$LIST_ID"'", "title": "Write docs", "due_date": "2026-06-01"}'

# List today's active tasks
curl -G http://localhost:6543/api/tasks \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'view=today'

# Search tasks
curl -G http://localhost:6543/api/tasks \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'q=docs'

# Complete / reopen
curl -X POST http://localhost:6543/api/tasks/$TASK_ID/complete -H "Authorization: Bearer $TOKEN"
curl -X POST http://localhost:6543/api/tasks/$TASK_ID/reopen   -H "Authorization: Bearer $TOKEN"
```

Referencing a `list_id` you do not own returns `422 list_not_found`.

### Note folders

| Method & path                  | Description                                          |
| ------------------------------ | ---------------------------------------------------- |
| `GET /api/note-folders`        | List all folders.                                    |
| `POST /api/note-folders`       | Create a folder.                                     |
| `GET /api/note-folders/:id`    | Fetch one folder.                                    |
| `PATCH /api/note-folders/:id`  | Update a folder.                                     |
| `DELETE /api/note-folders/:id` | Delete a folder (fails if it has active notes).      |

**Fields:** `name` (required, 1–80 chars), `position` (integer). `is_default` is
read-only.

```bash
curl -X POST http://localhost:6543/api/note-folders \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name": "Research", "position": 1}'
```

Deleting a folder that still has active (non-deleted) notes returns `422 folder_has_notes`.

### Notes

| Method & path                    | Description                                       |
| -------------------------------- | ------------------------------------------------- |
| `GET /api/notes`                 | List notes (supports filters, see below).         |
| `POST /api/notes`                | Create a note.                                    |
| `GET /api/notes/:id`             | Fetch one note.                                   |
| `PATCH /api/notes/:id`           | Update a note.                                    |
| `DELETE /api/notes/:id`          | **Soft delete** (sets `deleted_at`).              |
| `POST /api/notes/:id/pin`        | Pin a note.                                       |
| `POST /api/notes/:id/unpin`      | Unpin a note.                                     |
| `POST /api/notes/:id/restore`    | Restore a soft-deleted note.                      |
| `DELETE /api/notes/:id/permanent`| **Hard delete** (irreversible).                   |

**Fields:** `folder_id` (required, must be a folder you own), `title` (required, 1–255
chars), `body` (≤ 100,000 chars), `pinned` (boolean), `position` (integer).

**Query filters for `GET /api/notes`:**

| Param       | Values / format         | Effect                                            |
| ----------- | ----------------------- | ------------------------------------------------- |
| `deleted`   | `true` \| `false`       | Show soft-deleted notes (default `false`).        |
| `folder_id` | UUID                    | Only notes in that folder.                        |
| `pinned`    | `true` \| `false`       | Filter by pinned state.                           |
| `q`         | text                    | Case-insensitive search of title and body.        |

Notes are returned pinned-first, then most-recently-updated.

```bash
# Create
curl -X POST http://localhost:6543/api/notes \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"folder_id": "'"$FOLDER_ID"'", "title": "Meeting notes", "body": "## Agenda"}'

# Soft delete, then restore
curl -X DELETE http://localhost:6543/api/notes/$NOTE_ID            -H "Authorization: Bearer $TOKEN"
curl -X POST   http://localhost:6543/api/notes/$NOTE_ID/restore    -H "Authorization: Bearer $TOKEN"

# List notes in the trash
curl -G http://localhost:6543/api/notes \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'deleted=true'

# Permanently delete
curl -X DELETE http://localhost:6543/api/notes/$NOTE_ID/permanent  -H "Authorization: Bearer $TOKEN"
```

## WebSocket realtime API

Todex exposes the same mutations over an authenticated WebSocket at:

```
GET /api/ws
```

The connection starts **unauthenticated**. The client authenticates with a first message
(no token is ever placed in the URL), then sends command envelopes. Successful mutations
are broadcast to all of the user's connected clients.

### Handshake

```json
// → client sends first
{ "type": "auth", "payload": { "token": "<jwt>" } }

// ← server replies on success
{ "type": "auth_ok" }
```

Any command sent before a successful handshake is rejected with an `unauthorized` error
envelope. To limit brute force, a single connection that fails auth repeatedly stops being
checked after a few attempts.

### Sending a command

```json
// → client
{ "id": "c1", "type": "task:create", "payload": { "list_id": "…", "title": "Buy milk" } }

// ← server (direct reply to the sender)
{ "id": "c1", "type": "ok", "payload": { "task": { "id": "…", "title": "Buy milk" } } }

// ← server (broadcast to all of the user's connections)
{ "type": "task:created", "payload": { "task": { "id": "…", "title": "Buy milk" } } }
```

A minimal browser client:

```javascript
const ws = new WebSocket("ws://localhost:6543/api/ws");

ws.onopen = () => ws.send(JSON.stringify({ type: "auth", payload: { token } }));

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  if (msg.type === "auth_ok") {
    ws.send(JSON.stringify({
      id: "c1",
      type: "task:create",
      payload: { list_id: listId, title: "Buy milk" },
    }));
  } else {
    console.log("received", msg); // ok / error replies and broadcasts
  }
};
```

The full list of commands, payloads, error shapes, and broadcast events is documented in
[`docs/api/websocket-protocol.md`](docs/api/websocket-protocol.md).

## OpenAPI & Swagger UI

- **OpenAPI JSON:** `GET /api/openapi`
- **Swagger UI** (enabled in dev/test): `GET /swaggerui`

```bash
curl http://localhost:6543/api/openapi | jq .
open http://localhost:6543/swaggerui
```

Both are disabled by default in production (toggle with the `:swagger_ui_enabled` app
config).

## Testing

```bash
mix test
```

Tests run against a sandboxed PostgreSQL database (`todex_test`) and cover the REST and
WebSocket surfaces, authentication lifecycle, cross-user access (IDOR) protection, input
validation, and rate limiting. Rate limiting is disabled by default in the test
environment.

## Project layout

```
lib/
  todex/                 # Domain contexts (pure business logic)
    accounts.ex          # Users, JWT issue/verify/revoke
    onboarding.ex        # Registration orchestration (user + default data + token)
    todos.ex             # Lists & tasks
    notes.ex             # Note folders & notes
    realtime.ex          # Per-user broadcast registry
  todex_web/             # Web layer
    router.ex            # HTTP routes + auth/login + OTP boot
    web_socket_handler.ex# WebSocket auth handshake & command dispatch
    realtime/            # WebSocket command handler
    auth_plug.ex         # Bearer-token authentication plug
    errors.ex            # Shared error mapping & rendering
    rate_limit.ex        # ETS-backed per-IP rate limiter
    json.ex              # Response serializers
priv/repo/migrations/    # Database schema
docs/api/                # Protocol documentation
```
