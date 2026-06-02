# Inspector review-update — add-resource-sharing

Reviewed: 2026-06-01. Two specialists (structural+consistency, codebase-alignment+gaps) ran in parallel; all codebase claims were verified against source before patching.

**Verdict: ready** — no Critical findings remain unresolved. All actionable findings were patched (auto or user-guided). Remaining items are minor follow-ups noted below.

## Verified codebase facts (informed the patches)

- `tasks(list_id, user_id) → lists(id, user_id)` composite FK (`priv/repo/migrations/*create_tasks.exs`) hard-enforces that a task's `user_id` equals its list owner's. Editor-created shared-list tasks **must** use the list owner's id; `Todos.create_task` currently sets `user_id: user.id` (lib/todex/todos.ex:107). Captured by tasks 3.5 + the "Editor-created shared-list task ownership" scenario.
- `validate_list_owner`/`get_list` are owner-only (lib/todex/todos.ex:169-199) — must become actor-permission-aware without reopening IDOR for foreign lists.
- Realtime broadcast is hard-coded to the acting user: `Todex.Realtime.broadcast(user.id, ...)` (lib/todex_web/web_socket_handler.ex:101); `CommandHandler` returns recipient-less broadcasts. Fanout needs the broadcast contract to carry target user ids. Registry is keyed by user_id (reusable).
- Goal recompute keys on the actor `user` (lib/todex/todos.ex:128-132); for editor-driven edits this resolves the wrong user. Must key on the list owner.
- Existing tables use `on_delete: :delete_all`.
- **notes.ex and goals.ex already exist** — the design context correctly assumes they exist. (One specialist flagged a missing dependency on `add-notes-api`/`add-goals-api`; this was a **false alarm** and was not patched.)

## Patches applied

10 findings auto-patched. 4 findings patched after user guidance. 0 skipped.

### Auto-patched
1. **Share table cascade behavior** — `tasks.md:5` (1.3) → specify `on_delete: :delete_all` for list/note and owner/recipient user FKs; added "Share cleanup on resource or user deletion" scenario to `resource-sharing/spec.md`.
2. **Goal recompute owner resolution** — `tasks.md:27` (3.8) → recompute resolves affected goals by the list owner's id, not the acting editor's.
3. **Shared-resource serializer reuse** — `tasks.md:43` (5.4) → reuse one response shape for REST listings and `list:shared`/`note:shared` events.
4. **Broadcast fanout contract** — `tasks.md:51` (6.1) → write results must carry target recipient user ids (handler currently broadcasts only to the actor).
5. **Revocation event naming** — `tasks.md:57` (6.7) + `realtime/spec.md` "Share revocation fanout" → named `list:unshared`/`note:unshared`.
6. **Unauthenticated access** — `rest-api/spec.md` → added "Unauthenticated sharing request" → `unauthorized` scenario.
7. **Revoked-task ownership** — `resource-sharing/spec.md` → added "Editor-created task after share revocation" scenario (tasks stay owner-owned).
8. **Recipient self-removal** — `resource-sharing/spec.md` → added negative scenario (V1 non-goal: only owner revokes).
9. **Error→status mapping** — `design.md` → added a sharing error-code → HTTP-status mapping decision.
10. **Editor share management** — confirmed already covered by "Recipient manages shares → not_found" (an editor is a recipient); no change beyond #8.

### User-guided patches
1. **Stale Open Questions** — `design.md:175` → converted the three Open Questions into Resolved Decisions matching the deltas (owner id+email exposed; editors may set list `position`; note editors may edit title+body). _(user chose: resolve per deltas)_
2. **Realtime command scope** — `realtime/spec.md` "Supported Commands" → narrowed header to "list and task mutation commands" with owner-or-editor checks (matches the scenarios present and the canonical spec). _(user chose: narrow header)_
3. **Email-enumeration hardening** — share creation now returns a uniform `202` neutral acknowledgment ("if that user exists, the resource has been shared with them") whether or not the recipient is registered; removed `user_not_found`. Updated `resource-sharing/spec.md` (Existing/Unknown recipient), `rest-api/spec.md` (Create list/note share, Unregistered recipient), `design.md` mapping, and `tasks.md:67` (7.3). _(user chose: neutral acknowledgment message)_
4. **Pagination** — added "Paginated shared listings" scenario to `resource-sharing/spec.md`, a pagination scenario to `openapi/spec.md`, and updated `tasks.md:42` (5.3) and 7.3. _(user chose: add pagination requirement)_

## Remaining follow-ups (minor, not blocking)

- **Residual enumeration oracle**: `share_already_exists` (409) and `cannot_share_with_self` (422) still reveal information to a probing owner. Deemed acceptable for V1 since the owner already has context about their own shares. Revisit if stricter privacy is required.
- **Implementation note**: an editor's own shared-list mutation must broadcast to the owner + other recipients (not just back to the editor); the per-user registry (keyed by user_id) supports this once the broadcast contract carries recipient ids (task 6.1).
- **IDOR**: WS `task:create` with an arbitrary `list_id` must authorize via the new shared-list permission path while still returning not_found for foreign/non-shared lists (task 3.5 + existing ws_idor tests).
