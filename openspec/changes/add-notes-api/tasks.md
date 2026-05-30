## 1. Data Model

- [x] 1.1 Create migration for `note_folders` with uuid id, user_id, name, position, is_default, timestamps, foreign key, and per-user name uniqueness.
- [x] 1.2 Create migration for `notes` with uuid id, user_id, folder_id, title, body text, pinned, position, deleted_at, timestamps, foreign keys, and query indexes.
- [x] 1.3 Add `Todex.Notes.NoteFolder` schema and changeset validations.
- [x] 1.4 Add `Todex.Notes.Note` schema and changeset validations.

## 2. Notes Context

- [x] 2.1 Add `Todex.Notes.seed_default_folders/2` and `/1` to create the default `Notes` folder.
- [x] 2.2 Add note folder CRUD context functions scoped to the authenticated user.
- [x] 2.3 Add note folder deletion guard that rejects folders with active notes using `folder_has_notes`.
- [x] 2.4 Add note CRUD context functions scoped to the authenticated user.
- [x] 2.5 Add note folder ownership validation for note creation and updates with `folder_not_found` errors.
- [x] 2.6 Add note listing filters for folder_id, q, pinned, and deleted, including invalid filter handling.
- [x] 2.7 Add note pin, unpin, soft delete, restore, and permanent delete context functions.

## 3. Registration Integration

- [x] 3.1 Update user registration transaction to seed default note folders along with default todo lists and auth token.
- [x] 3.2 Add account tests proving registration creates default todo lists, default note folder, token, and rolls back on failure.

## 4. Serialization and Errors

- [x] 4.1 Add JSON serializers for note folders and notes with stable fields and ISO datetime formatting.
- [x] 4.2 Extend error rendering for `folder_not_found` and `folder_has_notes` in REST responses.
- [x] 4.3 Extend realtime command error mapping for `folder_not_found` and `folder_has_notes`.

## 5. REST API

- [x] 5.1 Add protected `/api/note-folders` routes for list and create.
- [x] 5.2 Add protected `/api/note-folders/:id` routes for get, update, and delete.
- [x] 5.3 Add protected `/api/notes` routes for list and create with supported query parameters.
- [x] 5.4 Add protected `/api/notes/:id` routes for get, update, and soft delete.
- [x] 5.5 Add protected note action routes for pin, unpin, restore, and permanent delete.
- [x] 5.6 Add REST API tests covering note folder lifecycle, note lifecycle, filters, pinning, soft deletion, restore, permanent deletion, ownership, and error responses.

## 6. OpenAPI

- [x] 6.1 Add OpenAPI schemas for `NoteFolder`, `Note`, `NoteFolderRequest`, and `NoteRequest`.
- [x] 6.2 Add OpenAPI paths and operation ids for note folder endpoints.
- [x] 6.3 Add OpenAPI paths and operation ids for note endpoints and note action endpoints.
- [x] 6.4 Add OpenAPI query parameters for `GET /api/notes`: folder_id, q, pinned, and deleted.
- [x] 6.5 Extend OpenAPI tests to assert note schemas, note paths, operation ids, security, query parameters, and response statuses.

## 7. Realtime

- [x] 7.1 Extend realtime command handler for note folder create, update, and delete commands.
- [x] 7.2 Extend realtime command handler for note create, update, delete, pin, unpin, restore, and permanent delete commands.
- [x] 7.3 Add realtime tests for successful note folder and note commands with ok responses and broadcasts.
- [x] 7.4 Add realtime tests for note validation, `folder_not_found`, `folder_has_notes`, and ownership failures.
- [x] 7.5 Update WebSocket protocol documentation with note commands, responses, and broadcast events.

## 8. Verification

- [x] 8.1 Run migrations in test setup and verify schema tests cover note folder and note validations.
- [x] 8.2 Run the full test suite with `mix test`.
- [x] 8.3 Regenerate or verify `openapi.json` if this project treats it as a checked-in artifact.
- [x] 8.4 Run `openspec validate --all` to verify the change artifacts and main specs remain valid.
