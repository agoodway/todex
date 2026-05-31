## Context

Todex has two independent domain contexts — `Todos` (lists, tasks) and `Notes` (folders, notes) — each following the same mold: `binary_id` schemas, per-user ownership, REST + WebSocket command APIs, OpenApiSpex documentation, and IDOR coverage. WebSocket mutations broadcast a single per-user event through `TodexWeb.Realtime.CommandHandler.result/4`, which returns one `%{type, payload}` broadcast tuple per command. REST mutations do not broadcast.

Goals introduces a third domain, but unlike the existing two it is *not* independent: a goal's `progress` is derived from the completion state of the tasks linked to it through a many-to-many relationship. This couples the `Todos` write path to goal state and breaks the "one broadcast per command" assumption, because completing a single task can move several goals at once.

## Goals / Non-Goals

**Goals:**
- A flat, per-user `goals` resource with `title`, `description`, `reason`, and a derived `progress` percentage.
- A many-to-many task↔goal association via a `goal_tasks` join table scoped by `user_id`.
- Progress derived as `0` when a goal has no linked tasks, otherwise `round(completed / total * 100)`, reaching `100` only when all linked tasks are completed. No separate completion state.
- `Todos` owns recomputation: every task write that touches linked goals recomputes each affected goal in the same transaction.
- WebSocket fan-out: a task command broadcasts its `task:*` event plus one `goal:updated` event per affected goal; link/unlink broadcast only the affected `goal:updated`.

**Non-Goals:**
- No goal grouping/containers, no goal hierarchy, no goal completion timestamp or archival state.
- No manual progress override — progress is always derived.
- No REST broadcasting (broadcasts remain a WebSocket-only concern, consistent with existing behavior).
- No goal-level filtering/search views beyond standard listing.

## Decisions

### Data model: `goals` + `goal_tasks` join
- `goals`: `id` (binary_id), `user_id`, `title`, `description`, `reason`, `progress` (integer 0–100, default 0), timestamps.
- `goal_tasks`: `id` (binary_id), `user_id`, `goal_id`, `task_id`, timestamps; unique index on `(goal_id, task_id)`; supporting indexes on `goal_id`, `task_id`, and `user_id`.
- **Why carry `user_id` on the join:** both endpoints are already user-scoped, but denormalizing `user_id` onto the join keeps IDOR checks and affected-goal queries single-table and cheap, which matters given how often task writes will touch it. Alternative (derive ownership by joining through `goals`/`tasks`) was rejected as more expensive on the hot path.
- The `tasks` table is unchanged — no `goal_id` column — because the relationship is many-to-many.

### Progress is persisted and recomputed transactionally
- `progress` is stored on the goal row and recomputed whenever its linked task set or any linked task's completion state changes.
- **Why persist instead of compute-on-read:** reads (listing/showing goals) stay trivial, and the broadcast payload is just the current row. The cost is drift risk, mitigated by always recomputing inside the same `Ecto.Multi`/transaction as the triggering write (see below). Compute-on-read was considered (driftless, no column) but still requires computing a snapshot to broadcast and pushes per-goal aggregation into every goal read; persisting was preferred for read simplicity and a stable broadcast payload.
- Recompute query per goal: count linked tasks and count completed linked tasks via the join, then `progress = total == 0 ? 0 : round(completed / total * 100)`.

### `Todos` owns recompute; affected goals surface in the return value
- Task writes (`create_task`, `update_task`, `complete_task`, `reopen_task`, `delete_task`) recompute every goal linked to the affected task within the same transaction, so REST and WebSocket callers both keep goal progress correct.
- **Why surface affected goals:** the WebSocket layer must broadcast the goals that moved, so the context functions return the affected goal records (e.g. an `{:ok, task, affected_goals}`-style result, or a result struct) in addition to the task. REST ignores the extra data; the command handler uses it to fan out. Alternative (have the web layer re-query affected goals after the write) was rejected because it duplicates the join logic and risks a different result than what the transaction computed.
- For `delete_task`, the set of affected goals is captured *before* deletion (the join rows are about to disappear); each such goal is recomputed after the task and its join rows are removed.

### Association lives in a new `Goals` context; link/unlink as a goals sub-resource
- New `Todex.Goals` context owns goal CRUD, the `goal_tasks` join schema, link/unlink operations, and the shared `recompute_progress/2` helper that `Todos` calls.
- **Why a separate context calling back into recompute:** keeps goal CRUD cohesive in `Goals` while letting `Todos` own the *trigger* (it already owns task writes). `Todos` depends on a focused `Goals.recompute_progress` function rather than reaching into goal schemas directly.
- Link/unlink REST: `POST /api/goals/:id/tasks` (body `{task_id}`) and `DELETE /api/goals/:id/tasks/:task_id`. Both validate that the goal and task are owned by the user (foreign ids behave as not found), recompute the goal, and return the updated goal.
- The join is **not** a first-class resource: there is no join read endpoint and no `goal_task:*` events; link/unlink simply produce a `goal:updated` for the affected goal.

### WebSocket broadcast fan-out (breaks one-broadcast-per-command)
- `CommandHandler.result/4` currently returns a single broadcast tuple. It must support **zero or more** broadcasts per command. The handler return contract changes to carry a list of broadcast events; `TodexWeb.WebSocketHandler` iterates and sends each.
- New commands use the existing colon naming convention:
  - `goal:create` → `goal:created`, `goal:update` → `goal:updated`, `goal:delete` → `goal:deleted`.
  - `goal:link_task` and `goal:unlink_task` → `goal:updated` for the affected goal.
  - `task:create|update|complete|reopen|delete` → existing `task:*` event **plus** one `goal:updated` per affected goal.
- Reassigning a task between goals is modeled as unlink + link; each affected goal recomputes and broadcasts independently (two `goal:updated` events).

### Deletion semantics
- Delete goal: `Goals.delete_goal` deletes the goal and its `goal_tasks` rows (DB-level `ON DELETE` cascade on the join's `goal_id` FK or explicit delete in the transaction). Linked tasks are untouched.
- Delete task: capture linked goals, delete the task and its `goal_tasks` rows (cascade on `task_id`), then recompute each previously-linked goal and broadcast.

### OpenAPI & seeding
- Add goal response/request schemas, `/api/goals` and `/api/goals/{id}` paths, and the link/unlink operations with operation ids, mirroring existing schema/path conventions.
- No default goals are seeded for new users (goals are user-authored objectives, unlike default lists/folders).

## Risks / Trade-offs

- [Persisted progress can drift from reality] → Always recompute inside the same transaction as the triggering write; never update completion state and progress on separate paths. A `mix` task or test can assert stored progress equals recomputed progress.
- [Broadcast fan-out changes a core realtime contract] → Generalize the broadcast return to a list once and route all existing single-event commands through it unchanged; cover with realtime tests asserting both the `task:*` and the per-goal `goal:updated` events fire.
- [Changing `Todos` task-write return shape touches REST + WS call sites] → Keep the task record in the same position and add affected goals as additional data the REST layer can ignore; update call sites in one pass with tests.
- [Large fan-out: a task linked to many goals emits many broadcasts] → Acceptable for the expected scale (personal task manager); each event is small and scoped to the single user's transports.
- [Concurrent task writes racing on the same goal's progress] → Recompute reads the authoritative counts at write time inside a transaction, so the last committed write reflects the true count; no incremental delta math that could desync.
