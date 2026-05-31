## Why

Todex lets users capture tasks and notes, but it has no way to express the higher-level objectives those tasks serve or to see how much of an objective has been accomplished. Adding a goals API gives users a first-class place to record what they are trying to achieve and why, and to watch progress advance automatically as the tasks behind a goal get completed.

## What Changes

- Add goals as a flat, per-user resource with `title`, `description`, `reason`, and a derived `progress` percentage.
- Associate tasks and goals through a many-to-many relationship: a task can advance many goals and a goal can be advanced by many tasks.
- Derive `progress` from a goal's linked tasks: `0%` when no tasks are linked, otherwise the rounded percentage of linked tasks that are completed, reaching `100%` only when every linked task is completed. Progress is a number with no separate completion state.
- Make the `Todos` context own progress recomputation: any task write (create, update, complete, reopen, delete) that touches linked goals recomputes each affected goal and returns those affected goals so the WebSocket layer can broadcast a `goal:updated` event per affected goal, alongside the existing `task:*` broadcast. REST callers ignore the affected-goals data and do not broadcast.
- Add protected REST endpoints for goal CRUD and for linking/unlinking a task to a goal as a goals sub-resource (`POST /api/goals/:id/tasks`, `DELETE /api/goals/:id/tasks/:task_id`).
- Add realtime commands for goal CRUD and task link/unlink that mirror REST behavior; link/unlink are not their own broadcast resource and instead broadcast the affected `goal:updated` event.
- Clean up associations on deletion: deleting a goal drops its join rows and leaves tasks untouched; deleting a task drops its join rows and recomputes and broadcasts every goal it was linked to.
- Extend OpenAPI output with goal schemas, request schemas, paths, operations, and documented responses.
- No breaking changes to existing auth, todo list, task, note, REST, OpenAPI, or realtime behavior.

## Capabilities

### New Capabilities
- `goals`: Per-user goals with CRUD, ownership scoping, a derived progress percentage, a many-to-many task association with link/unlink operations, and progress recomputation with realtime broadcast on task and association changes.

### Modified Capabilities
- `todo-tasks`: Task writes recompute the progress of every goal a task is linked to and broadcast the affected goals; deleting a task drops its goal associations.
- `rest-api`: Protected REST API gains goal endpoints and task link/unlink sub-resource endpoints using existing JSON envelope and error conventions.
- `openapi`: OpenAPI document gains goal schemas, goal paths, goal operation ids, and link/unlink operations.
- `realtime`: WebSocket command protocol gains goal mutation commands and task link/unlink commands, plus `goal:updated` broadcast events.

## Impact

- Domain: new `Todex.Goals` context with a goal schema and a `goal_tasks` join schema; `Todex.Todos` gains recompute-and-return-affected-goals logic on task writes.
- Database: new `goals` and `goal_tasks` tables with user ownership; the join table carries `user_id` for scoping and uniqueness on `(goal_id, task_id)`, with cascade/cleanup of join rows on goal or task deletion.
- REST API: protected router gains `/api/goals` routes and `/api/goals/:id/tasks` link/unlink routes.
- OpenAPI: API spec and schema modules gain goal resources and request/response documentation.
- Realtime: command handler and protocol documentation gain goal commands, task link/unlink commands, and `goal:updated` events with fan-out across multiple goals per task write.
- Tests: schema, context, REST, OpenAPI, IDOR, and realtime command coverage expands for goals, associations, and progress recomputation.
