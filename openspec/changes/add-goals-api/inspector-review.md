# Inspector Review — add-goals-api

**Reviewed:** 2026-05-31
**Reviewer:** inspector/review-update
**Verdict:** Ready to implement

## Summary

The change proposes a new per-user goals API with derived progress from linked tasks, REST and realtime surfaces, and OpenAPI coverage. The quick review found no critical blockers. All findings were patchable after one user-guided database-design decision, and the artifacts now better match existing event naming, REST/realtime conventions, timestamp schema coverage, and current database ownership patterns.

**Counts:** Critical: 0 · Warning: 9 · Suggestion: 2

## Scope inspected

- Proposal: `openspec/changes/add-goals-api/proposal.md`
- Design: `openspec/changes/add-goals-api/design.md`
- Tasks: `openspec/changes/add-goals-api/tasks.md`
- Deltas: `goals`, `todo-tasks`, `rest-api`, `realtime`, `openapi`
- Canonical specs consulted: `todo-tasks`, `rest-api`, `realtime`, `openapi`
- Other active changes consulted: `add-notes-api`
- Codebase context consulted: `Todex.Todos`, task schema/migrations, REST router, JSON serializers, realtime command handler, WebSocket handler, OpenAPI schemas/spec modules, existing tests

## Critical

_None._

## Warning

_None._

## Suggestion

_None._

## Patches applied

11 findings were patched. 10 findings were auto-patched. 1 finding was patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Proposal broadcast ownership and event naming** — `openspec/changes/add-goals-api/proposal.md:10` → clarified that `Todos` recomputes and returns affected goals, while the WebSocket layer broadcasts `goal:updated`; REST does not broadcast.
2. **Proposal link/unlink event naming** — `openspec/changes/add-goals-api/proposal.md:12` → changed `goal.updated` to `goal:updated`.
3. **Proposal realtime capability event naming** — `openspec/changes/add-goals-api/proposal.md:26` → changed `goal.updated` to `goal:updated`.
4. **Proposal domain impact wording** — `openspec/changes/add-goals-api/proposal.md:30` → replaced recompute-and-broadcast language with recompute-and-return-affected-goals language.
5. **Proposal deletion cleanup wording** — `openspec/changes/add-goals-api/proposal.md:31` → changed nullify/cleanup to cascade/cleanup for join rows.
6. **Proposal realtime impact event naming** — `openspec/changes/add-goals-api/proposal.md:34` → changed `goal.updated` to `goal:updated`.
7. **Todo task update side effect scenario** — `openspec/changes/add-goals-api/specs/todo-tasks/spec.md:15` → added a scenario requiring linked-goal recomputation when `update_task` changes completion state.
8. **OpenAPI goal timestamps** — `openspec/changes/add-goals-api/specs/openapi/spec.md:8` → added `inserted_at` and `updated_at` to the `Goal` schema field requirement.
9. **REST validation and unlink missing association scenarios** — `openspec/changes/add-goals-api/specs/rest-api/spec.md:22` and `openspec/changes/add-goals-api/specs/rest-api/spec.md:44` → added scenarios for goal validation failures and unlinking a missing association.
10. **Realtime affected-goal fan-out and not-found behavior** — `openspec/changes/add-goals-api/specs/realtime/spec.md:36` and `openspec/changes/add-goals-api/specs/realtime/spec.md:56` → aligned fan-out wording to every affected recomputed goal and added missing/foreign goal command `not_found` behavior.

### User-guided patches

1. **Goal task database ownership enforcement** — `openspec/changes/add-goals-api/tasks.md:6` → added composite-FK implementation work for `goal_tasks.goal_id/user_id` and `goal_tasks.task_id/user_id`, matching existing task/note ownership enforcement. User chose: Composite FKs.

### Skipped

_None._

## Alignment notes

- **Other active changes:** `add-notes-api` also touches `rest-api`, `openapi`, and `realtime`, but no endpoint, schema, or command names collide with goals.
- **Canonical specs:** The deltas are additive against `todo-tasks`, `rest-api`, `openapi`, and `realtime`; no modified requirement conflicts were found.
- **Codebase assumptions verified:** Existing code uses `Todex.Todos`, `TodexWeb.Json`, `TodexWeb.Realtime.CommandHandler`, `TodexWeb.WebSocketHandler`, and `TodexWeb.ApiSpec` in the places named by the change. Existing migrations use composite FK ownership enforcement for task/list and note/folder relationships, which informed the user-guided database patch.

## What looks good

- The change keeps goals flat and avoids adding hierarchy, archival state, or manual progress overrides.
- Progress derivation is explicit, bounded, and recomputed transactionally on association and task-state changes.
- REST, realtime, and OpenAPI surfaces are scoped to existing project conventions.
- The design calls out the main architectural risk: changing single-event realtime broadcasts into fan-out.
