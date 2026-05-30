## Context

Todex is an Elixir API using Francis routes, Ecto schemas, PostgreSQL persistence, JWT bearer authentication, OpenAPI generation, and a WebSocket command handler for realtime mutations. The current domain model is task-oriented: users own todo lists and tasks, with REST and realtime APIs exposing list/task operations. Notes need a separate document-oriented model so freeform content, folder organization, pinning, search, and soft deletion do not distort todo task semantics.

## Goals / Non-Goals

**Goals:**
- Add a `Todex.Notes` context parallel to `Todex.Todos`.
- Add per-user note folders and notes with ownership checks equivalent to list/task scoping.
- Support Markdown/plain-text note bodies as text, with explicit titles and optional snippets derived during serialization.
- Support folder filtering, text search, pinned filtering, deleted filtering, soft delete, restore, and permanent delete.
- Extend existing REST, OpenAPI, and realtime patterns rather than introducing a second API style.
- Seed a default notes folder during registration in the same transaction as user creation.

**Non-Goals:**
- Rich-text block storage, CRDTs, collaborative editing, cursors, or operational transform.
- Attachments, images, handwritten notes, link previews, OCR, sharing, or locked notes.
- Reusing todo lists as note folders.
- Changing existing todo list, task, auth token, or JSON envelope behavior.

## Decisions

### Separate Notes Context

Create `Todex.Notes` with `NoteFolder` and `Note` schemas instead of extending `Todex.Todos`.

Rationale: tasks and notes have different lifecycle semantics. Tasks revolve around completion, due dates, and status; notes revolve around recency, search, pinning, and recoverability. A separate context keeps authorization and ownership patterns familiar without coupling note behavior to task constraints.

Alternative considered: reuse todo lists for note grouping. This would reduce table count but creates confusing behavior around list deletion, task-only metadata, and future notes-specific features.

### Markdown/Plain Text Body Stored as Text

Store note content in a `body` text field. Treat the body as Markdown-capable text at the API boundary, but do not parse or normalize Markdown server-side.

Rationale: this gives clients enough flexibility for headings, links, and checklist-like text while keeping the backend simple. It avoids committing to a block schema before editor requirements are known.

Alternative considered: rich JSON block documents. This is more Apple Notes-like long term, but it would increase validation, migration, and partial update complexity before collaboration or rich attachments are in scope.

### Explicit Title With Lightweight Fallback

Persist `title` as an explicit field and allow `body` to hold the full content. Require title for the first implementation, with clients responsible for deriving an Apple Notes-style first-line title if desired.

Rationale: the current API and OpenAPI patterns are simpler when required display names are explicit. Server-derived titles can be added later without changing storage.

Alternative considered: derive title from the first non-empty body line. This is more Apple Notes-like, but creates ambiguity around empty notes, title updates, and API validation.

### Soft Delete by Default

Use `deleted_at` to represent deleted notes. `DELETE /api/notes/{id}` sets `deleted_at`; restore clears it; permanent deletion removes the row.

Rationale: notes are durable user content. Apple Notes-style recovery is expected and hard delete as the default would be risky. This also supports a Recently Deleted view through `GET /api/notes?deleted=true`.

Alternative considered: hard delete only. It is simpler but makes accidental deletion unrecoverable and makes later recovery support more disruptive.

### Folder Deletion Requires Empty Active Notes

Reject deletion of a note folder that contains non-deleted notes. Allow deletion once active notes have moved, been soft-deleted, or been permanently deleted.

Rationale: this mirrors the existing todo list protection against deleting lists with tasks while respecting soft-deleted note recovery.

Alternative considered: cascade delete or soft-delete all contained notes. That is convenient but surprising and higher risk for user content.

### REST First, Realtime Mutation Broadcasts Only

Expose complete REST/OpenAPI support and add realtime commands for whole-note mutations. Do not add collaborative document editing.

Rationale: existing realtime infrastructure already broadcasts mutation events. Whole-record updates are enough for autosave-style clients and keep conflict handling client-owned.

Alternative considered: live editing protocol. This requires conflict resolution semantics that are out of scope.

## Risks / Trade-offs

- Large note bodies can make list responses heavy -> list serializers should include a stable body field only if required by spec, and clients can use search/filtering to reduce result sets. If this becomes expensive, add preview-only list responses later.
- Text search using `ilike` may not scale -> start with simple title/body search consistent with task search; add PostgreSQL full-text indexes later if needed.
- Required explicit titles are less Apple Notes-like -> clients can derive title from first line before sending; server-side derivation can be added as a future enhancement.
- Soft-deleted notes complicate folder deletion -> specify clear behavior: folders with active notes cannot be deleted; deleted notes remain recoverable or permanently deletable.
- Realtime note updates may conflict under concurrent autosave -> current scope broadcasts mutations but does not resolve document merge conflicts.

## Migration Plan

1. Add migrations for `note_folders` and `notes` with user ownership, folder ownership, soft delete, and query indexes.
2. Add schemas and `Todex.Notes` context functions.
3. Update registration transaction to seed a default notes folder.
4. Add serializers and REST routes.
5. Extend OpenAPI schemas and paths.
6. Extend realtime command handler and WebSocket protocol docs.
7. Add tests for schemas, context scoping, REST, OpenAPI, and realtime commands.

Rollback: drop the new notes tables and remove notes routes/commands before release if the feature is not shipped. Once shipped with data, rollback requires preserving or exporting notes data before removing endpoints.

## Open Questions

- Should list responses include full note bodies or only metadata/snippet? The initial implementation can include full bodies for consistency, but this is the first likely optimization point.
- Should default notes folder be named `Notes`, `All Notes`, or `Personal`? Use `Notes` unless product copy decides otherwise.
