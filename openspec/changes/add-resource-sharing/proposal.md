## Why

Todex currently treats every list, task, note, and goal as visible only to its owning user. Users need a way to collaborate on task lists and notes with other registered users while preserving clear ownership and preventing accidental destructive access.

## What Changes

- Add collaborative sharing for task lists and individual notes with existing registered users.
- Add `viewer` and `editor` share roles.
- Allow list viewers to read shared lists and their tasks.
- Allow list editors to update shared list metadata and fully manage tasks in the shared list, but not delete the shared list or manage shares.
- Allow note viewers to read shared notes.
- Allow note editors to update shared note content, but not delete, restore, move, pin/unpin, or manage shares.
- Keep shared resources owner-owned; collaborator-created tasks in a shared list belong to the list owner.
- Broadcast collaborative changes to the owner and all users with access to the shared resource.
- Exclude public links, unregistered email invitations, share acceptance flows, folder sharing, goal sharing, and recipient self-removal from V1.

## Capabilities

### New Capabilities
- `resource-sharing`: Sharing task lists and notes with existing registered users, role-based access rules, ownership semantics, and share lifecycle behavior.

### Modified Capabilities
- `rest-api`: Add REST endpoints for managing shares and listing shared resources.
- `todo-lists`: Allow authorized collaborators to read and update shared lists while preserving owner-only deletion and share management.
- `todo-tasks`: Allow authorized list collaborators to read and edit tasks in shared lists while creating owner-owned tasks.
- `realtime`: Fan out resource events to owners and users with active shares.
- `openapi`: Document sharing endpoints, shared resource views, request schemas, response schemas, and authorization errors.

## Impact

- Adds persistence for list shares and note shares.
- Updates list, task, and note authorization checks from owner-only to owner-or-share-based access.
- Adds REST routes for share management and shared resource listing.
- Updates realtime broadcasting to resolve all users affected by shared resource changes.
- Updates OpenAPI generation and tests for the new API surface.
- Requires tests for owner access, viewer restrictions, editor permissions, cross-user isolation, and realtime fanout.
