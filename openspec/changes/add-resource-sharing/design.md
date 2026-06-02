## Context

Todex currently uses direct `user_id` ownership for lists, tasks, note folders, notes, goals, and goal-task associations. Context functions accept the authenticated user and query records with owner-only predicates such as `record.user_id == user.id`.

Sharing changes that model from owner-only access to actor-based access. A request actor may be the owner, a viewer collaborator, or an editor collaborator. Records remain owner-owned even when collaborators can read or mutate them.

Task lists and notes have different shapes:

- Lists are containers. Sharing a list grants access to the list and its tasks.
- Notes are leaf resources. Sharing a note grants access to that note only, not to its folder.

Realtime broadcasting is currently user-scoped. Shared resources require broadcasts to reach the owner and all users with active access to the changed resource.

## Goals / Non-Goals

**Goals:**

- Share task lists and individual notes with existing registered users by email.
- Support `viewer` and `editor` roles.
- Preserve owner-owned rows and owner-only root deletion/share management.
- Allow shared-list editors to update list metadata and fully manage tasks in the shared list.
- Allow shared-note editors to update note content fields without lifecycle or organization operations.
- Expose shared resources through dedicated API views.
- Fan out realtime events for shared list/task/note changes.

**Non-Goals:**

- Public share links.
- Sharing with unregistered users.
- Email invitation delivery or share acceptance flows.
- Recipient self-removal from shared resources.
- Folder sharing, goal sharing, comments, presence, or conflict resolution.
- Per-recipient organization of shared notes or lists.

## Decisions

### Use explicit share tables per resource type

Create `list_shares` and `note_shares` instead of one polymorphic `shares` table.

Rationale:

- The codebase currently favors explicit schemas and direct Ecto queries.
- Separate tables allow real foreign keys to `lists` and `notes`.
- Permission queries differ by resource shape: list access is inherited by tasks, while note access is direct.

Alternatives considered:

- A generic polymorphic `shares` table would reduce duplication and make future resource types easier to add, but would weaken database constraints and complicate query logic.

### Keep resource ownership unchanged

Shared resources remain owned by the original owner. Collaborator-created tasks in shared lists use the list owner's `user_id`.

Rationale:

- Existing tables, serializers, and goal progress logic already model tasks as owned by one user.
- List sharing represents delegated access to the owner's list, not a transfer or copy.
- Owner-linked goal progress can continue to update when shared-list tasks change.

Alternatives considered:

- Assign collaborator-created tasks to the collaborator. This would break list/task ownership consistency and complicate list deletion, filtering, and goal progress.

### Represent permissions as owner, viewer, and editor checks

Authorization should be expressed in terms of the actor's permission on the target resource:

- `owner`: full control, including delete and share management.
- `viewer`: read-only access.
- `editor`: read/write access, excluding root deletion and share management.

For list tasks, permissions are inherited from the parent list.

Rationale:

- This keeps permission rules small and understandable.
- It avoids adding account/team membership concepts before they are needed.

Alternatives considered:

- Treat editors as co-owners. This conflicts with the requirement that editors cannot delete the shared root resource.
- Add granular permissions per action. This is more flexible but premature for V1.

### Use email for share creation

Share creation accepts a recipient email and resolves it to an existing user.

Rationale:

- Users know collaborator emails, not user UUIDs.
- Registered-user-only sharing avoids pending invitation state.

Alternatives considered:

- Accept `recipient_user_id`. This is simpler internally but a poor client contract.
- Create pending invites for unknown emails. This is out of scope for V1.

### Keep shared resources in dedicated views

Shared lists and notes should be listed through dedicated shared-resource endpoints rather than merged into owned list and note listing responses.

Rationale:

- Existing list and note endpoints currently mean "my owned resources".
- Dedicated views make owner vs collaborator behavior explicit.
- Shared notes do not belong to the recipient's folder tree.

Alternatives considered:

- Merge shared records into existing list endpoints with an `access` field. This is convenient but risks breaking existing clients and obscures ownership semantics.

### Make shared resource discovery both durable and realtime

Clients should learn about resources shared with them through both pull and push paths:

- Durable pull: `GET /api/shared/lists` and `GET /api/shared/notes` on app boot, reconnect, or manual refresh.
- Realtime push: `list:shared` and `note:shared` events sent to the recipient when a share is created while they are connected.

Rationale:

- Pull endpoints are the source of truth and cover offline users.
- Realtime events let connected clients update immediately without polling.
- The same shared-resource response shape can be reused by the list endpoint and share-created events.

Alternatives considered:

- Rely only on polling. This is simpler but makes live collaboration feel stale.
- Rely only on realtime. This fails for offline users and reconnect scenarios.

### Fan out broadcasts by affected resource access

Realtime write handling should resolve recipients from the affected resource and broadcast to the owner plus active share recipients.

Rationale:

- Current per-user registry can remain unchanged.
- The routing decision belongs near write results, where affected resources are known.

Alternatives considered:

- Register sockets to resource channels. This is more scalable for heavy collaboration but is a larger protocol change.

### Map sharing error codes to stable HTTP statuses

Sharing operations return stable logical error codes mapped to HTTP statuses:

- `share_already_exists` -> 409
- `cannot_share_with_self` -> 422
- `forbidden` -> 403
- recipient/foreign share management and inaccessible resources -> `not_found` (404)

Share creation does **not** distinguish registered from unregistered recipient emails: it returns a uniform `202` neutral acknowledgment ("if that user exists, the resource has been shared with them") to avoid email enumeration. A share is created only when the email resolves to a registered user; the owner confirms actual shares via `GET /api/lists/{id}/shares` (or the note equivalent).

Share-management endpoints hide resource existence with `not_found` for non-owners, while in-resource mutations (e.g. a viewer editing a shared list) return `forbidden`.

## Risks / Trade-offs

- Permission regressions across owner-only code paths -> Add focused tests for owner, viewer, editor, foreign user, and invalid id behavior for every shared operation.
- Shared-list task creation may surprise implementers because the actor is not the owner -> Centralize owner resolution through list permission lookup and assert created tasks use the list owner's id.
- Shared note organization can be confusing because recipients do not see the owner's folder -> Use a dedicated shared-notes response shape that includes owner/share metadata and does not expose folder management for recipients.
- Realtime fanout can duplicate events if the owner is also somehow present in share recipients -> De-duplicate user ids before broadcasting.
- Goal progress may change when collaborators edit shared-list tasks -> Treat this as intentional because tasks remain owner-owned; do not expose owner goals through list sharing.
- Separate share tables duplicate code -> Keep shared role validation and user lookup logic in a small sharing context while preserving explicit schemas.

## Migration Plan

1. Add `list_shares` and `note_shares` tables with role constraints, owner/recipient uniqueness, and foreign keys.
2. Introduce sharing context functions for resolving recipients, creating/updating/deleting shares, listing shares, and calculating actor permissions.
3. Update list, task, and note reads/writes to use actor permission checks where sharing applies.
4. Add REST and realtime surfaces after the domain permission behavior is covered by tests.
5. Regenerate OpenAPI after routes and schemas exist.

Rollback is straightforward before any shares are created. After deployment, rolling back requires dropping share rows or leaving unused share tables in place until a forward fix is deployed.

## Resolved Decisions

- Shared resource responses include **both** the owner's id and email. The share serializer exposes owner id plus the recipient/owner user subset (id, email).
- List editors **may** reorder the shared root list via `position`; `position` is part of the editable list metadata for editors (see `todo-lists` delta, "Shared-list editor update").
- Note editors **may** update both the note title and body; lifecycle and organization operations remain owner-only (see `resource-sharing` delta, "Note editor access").
