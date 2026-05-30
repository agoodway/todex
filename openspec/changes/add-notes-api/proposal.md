## Why

Todex currently supports task-oriented content, but it has no first-class way to store durable freeform notes like a lightweight Apple Notes experience. Adding a notes API creates a separate document-oriented surface for users to capture, organize, search, pin, and recover personal notes without overloading task semantics.

## What Changes

- Add note folders as a per-user organization primitive separate from todo lists.
- Add notes with title, Markdown/plain-text body, pinned state, ordering metadata, soft deletion, and timestamps.
- Add protected REST endpoints for note folder CRUD, note CRUD, pin/unpin, restore, and permanent deletion.
- Add filtering and search for notes by folder, query text, pinned state, and deleted state.
- Extend OpenAPI output with note schemas, request schemas, paths, operations, query parameters, and documented responses.
- Extend realtime command support with note folder and note mutation commands that mirror REST behavior and broadcast per-user events.
- Seed a default notes folder for new users.
- No breaking changes to existing auth, todo list, task, REST, OpenAPI, or realtime behavior.

## Capabilities

### New Capabilities
- `notes`: Per-user note folders and notes, including CRUD, search/filtering, pinning, soft deletion, restore, permanent deletion, ownership scoping, and default folder provisioning.

### Modified Capabilities
- `auth`: Registration provisions a default notes folder in addition to existing default todo lists.
- `rest-api`: Protected REST API gains note folder and note endpoints using existing JSON envelope and error conventions.
- `openapi`: OpenAPI document gains note schemas, note paths, note operation ids, and note query parameters.
- `realtime`: WebSocket command protocol gains note folder and note mutation commands and broadcast events.

## Impact

- Domain: new `Todex.Notes` context with note folder and note schemas.
- Database: new `note_folders` and `notes` tables with user ownership, folder relationship, indexes, and soft-delete support.
- Auth registration: user creation transaction seeds a default notes folder.
- REST API: protected router gains `/api/note-folders` and `/api/notes` routes.
- OpenAPI: API spec and schema modules gain note resources and request/response documentation.
- Realtime: command handler and protocol documentation gain note-related commands and events.
- Tests: schema, context, REST, OpenAPI, and realtime command coverage expands for notes behavior.
