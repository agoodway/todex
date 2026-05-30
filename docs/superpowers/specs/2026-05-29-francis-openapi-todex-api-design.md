# Francis OpenAPI Todex API Design

Date: 2026-05-29

## Scope

Turn `todex` into a Francis JSON API backed by PostgreSQL and Ecto. The API supports a todo UI with Today, Upcoming, Completed, list navigation, search, task creation, due dates, notes, and task/list assignment.

The first version includes authenticated users, task CRUD, list CRUD with seeded defaults, REST endpoints documented through `open_api_spex`, development-only Swagger UI, and a WebSocket API for realtime task/list commands.

OpenAPI documents the REST contract. WebSocket command semantics will be documented alongside the API because OpenAPI does not model Francis WebSocket message protocols well.

## Data Model

### `users`

Fields:

- `id`
- `email`
- `password_hash`
- `inserted_at`
- `updated_at`

Constraints:

- Unique `email`.

### `auth_tokens`

Fields:

- `id`
- `user_id`
- `token_hash`
- `expires_at`
- `inserted_at`

Purpose:

- Support JWT bearer authentication while allowing token revocation/logout and token lifecycle control.
- Store a hash of the JWT `jti` claim so logout can revoke individual tokens without persisting raw tokens.

### `lists`

Fields:

- `id`
- `user_id`
- `name`
- `icon`
- `color`
- `position`
- `is_default`
- `inserted_at`
- `updated_at`

Behavior:

- Seed default lists for each new user: Personal, Work, Fitness, Groceries.
- Users can add, rename, reorder, and delete custom lists.
- Default lists can be renamed and reordered.
- List deletion must be guarded. If tasks exist for the list, either reject deletion or require reassignment. The first implementation should reject deletion when tasks exist to keep behavior explicit.

Constraints:

- Unique list name per user.
- List ownership enforced through `user_id` in all queries.

### `tasks`

Fields:

- `id`
- `user_id`
- `list_id`
- `title`
- `notes`
- `status`
- `due_date`
- `completed_at`
- `position`
- `inserted_at`
- `updated_at`

Behavior:

- `status` starts as `active` or `completed`.
- Today, Upcoming, and Completed views are filters derived from `due_date` and `status`.
- Task ownership is enforced through `user_id`.
- List assignment must verify the target list belongs to the same user.

## REST API Surface

Authentication endpoints:

- `POST /api/auth/register` creates a user, seeds default lists, and returns a bearer token plus user.
- `POST /api/auth/login` returns a bearer token plus user.
- `POST /api/auth/logout` revokes the current token.
- `GET /api/me` returns the current user.

List endpoints:

- `GET /api/lists` returns lists ordered by `position`.
- `POST /api/lists` creates a custom list.
- `PATCH /api/lists/:id` updates `name`, `icon`, `color`, or `position`.
- `DELETE /api/lists/:id` deletes a list when deletion is allowed.

Task endpoints:

- `GET /api/tasks` returns tasks with filters.
- `POST /api/tasks` creates a task.
- `GET /api/tasks/:id` returns one task.
- `PATCH /api/tasks/:id` updates task fields.
- `DELETE /api/tasks/:id` deletes a task.
- `POST /api/tasks/:id/complete` marks a task completed.
- `POST /api/tasks/:id/reopen` marks a task active.

Supported `GET /api/tasks` filters:

- `view=today|upcoming|completed`
- `list_id`
- `q`
- `status`
- `due_before`
- `due_after`

OpenAPI/dev endpoints:

- `GET /api/openapi` renders the OpenAPI JSON spec.
- `GET /swaggerui` serves Swagger UI only in development. If conditional Francis routes are awkward, keep the route in all environments but return `404` unless `Mix.env() == :dev`.

## Realtime WebSocket API

Endpoint:

- `GET /api/ws`

Authentication:

- The client authenticates with a bearer token.
- The first version may pass the token as `?token=...` because browser WebSocket constructors cannot set arbitrary `Authorization` headers.
- The socket joins only when the token is valid.

Inbound command envelope:

```json
{
  "id": "client-command-id",
  "type": "task:create",
  "payload": {}
}
```

Successful command response:

```json
{
  "id": "client-command-id",
  "type": "ok",
  "payload": {}
}
```

Error command response:

```json
{
  "id": "client-command-id",
  "type": "error",
  "error": {
    "code": "validation_failed",
    "message": "Title can't be blank",
    "details": {}
  }
}
```

Broadcast event envelope:

```json
{
  "type": "task:updated",
  "payload": {}
}
```

Initial command set:

- `list:create`
- `list:update`
- `list:delete`
- `task:create`
- `task:update`
- `task:delete`
- `task:complete`
- `task:reopen`

Broadcast events:

- `list:created`
- `list:updated`
- `list:deleted`
- `task:created`
- `task:updated`
- `task:deleted`

Broadcast isolation:

- Broadcasts go only to sockets for the same authenticated user.
- Domain state remains in Postgres, not in socket processes.
- Socket handlers parse commands, call the same context functions as REST, then broadcast returned changes.

## Architecture

The application remains Francis-based and gains conventional OTP/Ecto structure.

### `Todex.Application`

Starts:

- `Todex.Repo`
- `Todex.Realtime`
- The Francis router/server

### `Todex.Repo`

Ecto repository for PostgreSQL.

### `Todex.Accounts`

Owns:

- Registration
- Password hashing
- Login
- Token issuing and verification
- Logout/revocation

### `Todex.Todos`

Owns:

- Lists
- Tasks
- Filtering
- Ordering
- Completion/reopening
- Ownership-safe mutations

### `TodexWeb.Router`

Francis HTTP/WebSocket boundary.

Responsibilities:

- Define REST and WebSocket routes.
- Authenticate protected routes.
- Decode request params.
- Call context functions.
- Render JSON responses.

Routes should stay thin. Business rules belong in contexts and schemas.

### `TodexWeb.ApiSpec`

Builds `%OpenApiSpex.OpenApi{}` manually.

Rationale:

- `open_api_spex` examples commonly use Phoenix router discovery through `Paths.from_router/1`.
- Francis uses Plug routes and macros, so explicit OpenAPI paths and operations are clearer and less fragile.

### `TodexWeb.Schemas`

OpenApiSpex schema modules for:

- Users
- Lists
- Tasks
- Auth requests/responses
- Error responses
- Mutation requests

### `TodexWeb.AuthPlug`

Validates bearer JWTs for REST routes and assigns the authenticated user to the connection.

### `TodexWeb.Errors`

Normalizes domain and validation errors into API response JSON.

### `Todex.Realtime`

A small PubSub-style registry for per-user socket transports.

Francis WebSocket `send(socket.transport, msg)` sends directly to the client, so the realtime layer stores socket transports by user and broadcasts encoded event maps.

## OpenAPI Integration

Dependencies and formatting:

- Add `{:open_api_spex, "~> 3.21"}`.
- Add Ecto/PostgreSQL dependencies.
- Add password hashing and JWT dependencies during implementation selection.
- Add `:open_api_spex` to `.formatter.exs` `import_deps`.

Spec setup:

- Add `OpenApiSpex.Plug.PutApiSpec` before documented API routes so downstream plugs can render the spec.
- Implement `TodexWeb.ApiSpec.spec/0` manually.

`TodexWeb.ApiSpec.spec/0` defines:

- `info`: Todex API title/version.
- `servers`: `%OpenApiSpex.Server{url: "/"}` for local relative usage.
- `components.securitySchemes`: bearer JWT auth.
- `paths`: explicit `%OpenApiSpex.PathItem{}` entries for every REST endpoint.
- `components.schemas`: resolved schema modules for users, lists, tasks, auth responses, errors, and mutation requests.

Routes:

- `GET /api/openapi` calls `OpenApiSpex.Plug.RenderSpec`.
- `GET /swaggerui` serves `OpenApiSpex.Plug.SwaggerUI` only in development.

## Error Handling

All API errors use this response shape:

```json
{
  "error": {
    "code": "not_found",
    "message": "Task not found",
    "details": {}
  }
}
```

REST status mapping:

- `400`: malformed params
- `401`: missing or invalid token
- `403`: ownership violation, if this is distinct from missing resource
- `404`: missing resource
- `422`: validation failure
- `500`: unexpected errors

For ownership failures, prefer returning `404` when revealing resource existence would be undesirable.

## Testing Strategy

Context tests:

- `Todex.Accounts` registration, login, token verification, logout.
- `Todex.Todos` list and task CRUD, filtering, ordering, completion, ownership checks.

REST tests:

- Use `Plug.Test` against the Francis router.
- Assert status and JSON body shape.
- Assert protected endpoints reject missing/invalid auth.
- Assert OpenAPI schema compatibility where practical.

WebSocket tests:

- Test command parsing and context dispatch directly.
- Add full socket integration tests after the command handler is separated from Francis transport details.

OpenAPI tests:

- Assert `/api/openapi` returns a valid spec.
- Assert expected paths exist.
- Assert bearer security scheme exists.

## Implementation Notes

- Use Postgres as the source of truth. Do not store task/list domain state in GenServers.
- Use Francis route handlers as an imperative shell around context functions.
- Keep `unmatched/1` last because it shadows routes declared after it.
- Use Francis JSON helpers or return maps/lists from handlers for JSON responses.
- For WebSockets, remember that `send(socket.transport, msg)` bypasses the handler and sends directly to the client.
- Avoid documenting WebSocket commands as first-class OpenAPI operations unless doing so as descriptive text only.

## Out Of Scope For First Version

- Collaborative sharing between users.
- Attachments.
- Recurring tasks.
- Reminders/notifications.
- Task subtasks.
- Offline sync conflict resolution.
- Full OpenAPI modeling of WebSocket message contracts.
