## 1. Database & Migrations

- [x] 1.1 Add a migration creating the `goals` table (`binary_id` pk, `user_id` fk, `title`, `description`, `reason`, `progress` integer default 0, timestamps) with a check constraint for `progress` between 0 and 100
- [x] 1.2 Add an index on `goals.user_id`
- [x] 1.3 Add a migration creating the `goal_tasks` join table (`binary_id` pk, `user_id` fk, `goal_id` fk, `task_id` fk, timestamps) with `ON DELETE` cascade on `goal_id` and `task_id`
- [x] 1.4 Add unique indexes on `goals (id, user_id)` and `tasks (id, user_id)` as composite FK targets, then enforce `goal_tasks.goal_id/user_id` and `goal_tasks.task_id/user_id` with composite foreign keys so cross-user joins are impossible at the database layer
- [x] 1.5 Add a unique index on `goal_tasks (goal_id, task_id)` and supporting indexes on `task_id` and `user_id`

## 2. Schemas

- [x] 2.1 Add `Todex.Goals.Goal` schema with fields, associations, and a `changeset/2` validating required `user_id`/`title`, title length 1–255, and casting only `title`/`description`/`reason` (never `progress`)
- [x] 2.2 Add `Todex.Goals.GoalTask` join schema with `user_id`/`goal_id`/`task_id`, a changeset, and unique-constraint handling on `(goal_id, task_id)`

## 3. Goals Context

- [x] 3.1 Add `Todex.Goals` context with `list_goals/1`, `get_goal/2`, `create_goal/2`, `update_goal/3`, `delete_goal/2`, all user-scoped (foreign/invalid ids return `:not_found`); ignore client-supplied progress
- [x] 3.2 Implement `link_task/3` and `unlink_task/3` validating goal and task ownership (return `:not_found` otherwise), idempotent on duplicate link, returning the updated goal
- [x] 3.3 Implement `recompute_progress/2` computing `0` for no linked tasks else `round(completed/total*100)`, updating the goal row; expose a helper to fetch goals linked to a given task id (user-scoped)
- [x] 3.4 Ensure goal deletion removes join rows and leaves tasks intact

## 4. Todos Recompute Integration

- [x] 4.1 Update `Todos.create_task`, `update_task`, `complete_task`, `reopen_task` to recompute every linked goal within the same transaction (use `Ecto.Multi`) and return the affected goals alongside the task
- [x] 4.2 Update `Todos.delete_task` to capture linked goals before deletion, delete the task and its join rows, recompute each previously-linked goal, and return the affected goals
- [x] 4.3 Keep the returned task in a stable position so the REST layer can ignore the affected-goals data
- [x] 4.4 Update REST and realtime task call sites to handle the chosen multi-result shape: REST serializes only the task, while `CommandHandler.result/4` emits the task event plus one `goal:updated` event per affected goal

## 5. REST API

- [x] 5.1 Add goal routes to the protected router: `GET/POST /api/goals`, `GET/PATCH/DELETE /api/goals/:id`
- [x] 5.2 Add link/unlink routes: `POST /api/goals/:id/tasks` (body `task_id`) and `DELETE /api/goals/:id/tasks/:task_id`, returning `data.goal`
- [x] 5.3 Add `Json.goal/1` serializer (id, title, description, reason, progress, inserted_at, updated_at) and wire `data.goal`/`data.goals` envelopes
- [x] 5.4 Map `:not_found` and validation errors to the existing REST error envelopes for goal endpoints

## 6. Realtime

- [x] 6.1 Generalize the command-handler/web-socket-handler broadcast contract to support a list of broadcast events per command, routing existing single-event commands through it unchanged
- [x] 6.2 Add `goal:create`/`goal:update`/`goal:delete` command dispatch broadcasting `goal:created`/`goal:updated`/`goal:deleted`
- [x] 6.3 Add `goal:link_task`/`goal:unlink_task` command dispatch broadcasting `goal:updated` for the affected goal
- [x] 6.4 Update `task:*` command dispatch to also broadcast one `goal:updated` per affected goal returned by the Todos write
- [x] 6.5 Add `record_payload(:goal, goal)` and any envelope helpers needed for goal payloads

## 7. OpenAPI

- [x] 7.1 Add `Goal` response schema and goal create/update and link-task request schemas to the schema module
- [x] 7.2 Add `/api/goals`, `/api/goals/{id}`, `/api/goals/{id}/tasks`, and `/api/goals/{id}/tasks/{task_id}` paths with operation ids, bearer auth, and 400/401/404/415/422 responses

## 8. Tests

- [x] 8.1 Goal schema tests (required fields, title length, progress bounds/default)
- [x] 8.2 Goals context tests for CRUD, ownership/IDOR, link/unlink idempotency, and progress recompute (0 with no tasks, partial rounding, 100 when all complete)
- [x] 8.3 Todos integration tests asserting complete/reopen/delete recompute linked goals and return affected goals (including multi-goal fan-out and no-goal cases)
- [x] 8.4 Todos integration tests asserting update_task recomputes linked goals when status/completed_at changes
- [x] 8.5 REST tests for goal CRUD, link/unlink, IDOR (foreign goal/task → 404), missing unlink association, validation errors, malformed JSON, missing/unsupported content types, and serialization fields
- [x] 8.6 Realtime tests asserting goal commands broadcast goal events, goal IDOR/not-found cases return `not_found`, and task commands emit `task:*` plus one `goal:updated` per affected goal
- [x] 8.7 OpenAPI tests asserting goal schemas, paths, operation ids, and protected security are present
- [x] 8.8 Run the full suite and the project quality checks (format, credo, dialyzer, tests)
