## 1. Data Model

- [x] 1.1 Add list share schema with owner, recipient, list, role, and timestamp fields
- [x] 1.2 Add note share schema with owner, recipient, note, role, and timestamp fields
- [x] 1.3 Add migrations for `list_shares` and `note_shares` with foreign keys (`on_delete: :delete_all` for the list/note references and for both owner and recipient user references) and role checks
- [x] 1.4 Add uniqueness constraints preventing duplicate shares per resource and recipient
- [x] 1.5 Add validation preventing self-sharing and invalid roles

## 2. Sharing Domain

- [x] 2.1 Add a sharing context for recipient lookup by normalized email
- [x] 2.2 Implement list share create, list, update, and delete functions
- [x] 2.3 Implement note share create, list, update, and delete functions
- [x] 2.4 Implement shared-list and shared-note listing for recipients
- [x] 2.5 Implement permission helpers for owner, viewer, and editor checks
- [x] 2.6 Map sharing errors to stable API and realtime error responses

## 3. List And Task Access

- [x] 3.1 Update list retrieval to support owner access and shared-list access paths
- [x] 3.2 Update list updates to allow owners and shared-list editors
- [x] 3.3 Keep list deletion owner-only and reject shared-list viewers/editors with `forbidden`
- [x] 3.4 Update task retrieval and listing to support tasks in shared lists
- [x] 3.5 Update task creation to allow shared-list editors and assign owner id from the target list
- [x] 3.6 Update task update, delete, complete, and reopen to allow shared-list editors
- [x] 3.7 Reject shared-list viewer task mutations with `forbidden`
- [x] 3.8 Preserve owner goal progress recomputation when shared-list tasks change, resolving affected goals by the list owner's id rather than the acting editor's id

## 4. Note Access

- [x] 4.1 Update note retrieval to support owner access and shared-note access paths
- [x] 4.2 Update note content edits to allow shared-note editors
- [x] 4.3 Restrict shared-note editors to title and body updates only
- [x] 4.4 Reject shared-note viewer mutations with `forbidden`
- [x] 4.5 Keep note soft delete, restore, permanent delete, pin, unpin, and folder movement owner-only
- [x] 4.6 Keep note folder access owner-only for V1

## 5. REST API

- [x] 5.1 Add list share management routes under `/api/lists/:id/shares`
- [x] 5.2 Add note share management routes under `/api/notes/:id/shares`
- [x] 5.3 Add paginated `GET /api/shared/lists` and `GET /api/shared/notes` with a bounded default page size and pagination metadata
- [x] 5.4 Add JSON serializers for shares and shared resource metadata, reusing one shared-resource response shape for both REST listings and `list:shared`/`note:shared` events
- [x] 5.5 Add request validation for share creation and role updates
- [x] 5.6 Add REST tests for owner share management and registered recipient lookup
- [x] 5.7 Add REST tests for viewer/editor permissions and root deletion protection
- [x] 5.8 Add REST tests for cross-user isolation and not-found behavior

## 6. Realtime

- [x] 6.1 Add recipient resolution for shared list, task, and note events, and extend the broadcast contract so write results carry target recipient user ids (the WebSocket handler currently broadcasts only to the acting user)
- [x] 6.2 Broadcast `list:shared` to connected recipients when a list share is created
- [x] 6.3 Broadcast `note:shared` to connected recipients when a note share is created
- [x] 6.4 Fan out shared list updates to owner and active share recipients
- [x] 6.5 Fan out shared task mutations to owner and active list share recipients
- [x] 6.6 Fan out shared note updates to owner and active note share recipients
- [x] 6.7 Broadcast `list:unshared`/`note:unshared` to revoked recipients on share revocation
- [x] 6.8 De-duplicate realtime broadcast recipients by user id
- [x] 6.9 Add realtime tests for shared editor commands and viewer rejections
- [x] 6.10 Add realtime tests for share-created discovery, broadcast fanout, and revocation events

## 7. OpenAPI And Verification

- [x] 7.1 Add OpenAPI schemas for shares, shared resources, and share requests
- [x] 7.2 Document sharing and shared-resource REST paths
- [x] 7.3 Document the `202` neutral share-creation acknowledgment, shared-listing pagination parameters, and `403`/`409` sharing-related error responses where applicable
- [x] 7.4 Regenerate `openapi.json`
- [x] 7.5 Run migrations in test setup if needed
- [x] 7.6 Run focused sharing, REST, realtime, and OpenAPI tests
- [x] 7.7 Run full test suite
- [x] 7.8 Run project quality checks
