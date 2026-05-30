## ADDED Requirements

### Requirement: Protected Note Folder Endpoints
The system SHALL expose protected note folder CRUD endpoints.

#### Scenario: List note folders endpoint
- **WHEN** an authenticated client requests `GET /api/note-folders`
- **THEN** the system returns `data.note_folders`

#### Scenario: Create note folder endpoint
- **WHEN** an authenticated client sends `POST /api/note-folders` with a valid JSON note folder body
- **THEN** the system returns 201 with `data.note_folder`

#### Scenario: Get note folder endpoint
- **WHEN** an authenticated client requests `GET /api/note-folders/{id}` for one of their note folders
- **THEN** the system returns `data.note_folder`

#### Scenario: Update note folder endpoint
- **WHEN** an authenticated client sends `PATCH /api/note-folders/{id}` with a valid JSON note folder body
- **THEN** the system returns 200 with `data.note_folder`

#### Scenario: Delete note folder endpoint
- **WHEN** an authenticated client sends `DELETE /api/note-folders/{id}` for an empty note folder
- **THEN** the system returns 200 with `data.note_folder` for the deleted note folder

### Requirement: Protected Note Endpoints
The system SHALL expose protected note CRUD and state-transition endpoints.

#### Scenario: List notes endpoint
- **WHEN** an authenticated client requests `GET /api/notes`
- **THEN** the system returns `data.notes`

#### Scenario: Note query parameters
- **WHEN** an authenticated client requests `GET /api/notes` with `folder_id`, `q`, `pinned`, or `deleted`
- **THEN** the system applies the supported note filters

#### Scenario: Create note endpoint
- **WHEN** an authenticated client sends `POST /api/notes` with a valid JSON note body
- **THEN** the system returns 201 with `data.note`

#### Scenario: Get note endpoint
- **WHEN** an authenticated client requests `GET /api/notes/{id}` for one of their notes
- **THEN** the system returns `data.note`

#### Scenario: Update note endpoint
- **WHEN** an authenticated client sends `PATCH /api/notes/{id}` with a valid JSON note body
- **THEN** the system returns 200 with `data.note`

#### Scenario: Delete note endpoint
- **WHEN** an authenticated client sends `DELETE /api/notes/{id}` for one of their notes
- **THEN** the system returns 200 with `data.note` for the soft-deleted note

#### Scenario: Pin note endpoint
- **WHEN** an authenticated client sends `POST /api/notes/{id}/pin`
- **THEN** the system returns 200 with `data.note` whose pinned flag is true

#### Scenario: Unpin note endpoint
- **WHEN** an authenticated client sends `POST /api/notes/{id}/unpin`
- **THEN** the system returns 200 with `data.note` whose pinned flag is false

#### Scenario: Restore note endpoint
- **WHEN** an authenticated client sends `POST /api/notes/{id}/restore`
- **THEN** the system returns 200 with `data.note` whose deleted_at value is null

#### Scenario: Permanently delete note endpoint
- **WHEN** an authenticated client sends `DELETE /api/notes/{id}/permanent`
- **THEN** the system returns 200 with `data.note` for the permanently deleted note

### Requirement: Note API Error Handling
The system SHALL use existing JSON error conventions for note API errors.

#### Scenario: Missing note resource
- **WHEN** a client requests, updates, deletes, pins, unpins, restores, or permanently deletes a note resource that is not found in their scope
- **THEN** the system returns 404 `not_found`

#### Scenario: Missing note folder assignment
- **WHEN** a client creates or updates a note with a note folder that is not found in their scope
- **THEN** the system returns 422 `folder_not_found`

#### Scenario: Delete folder with active notes
- **WHEN** a client deletes a note folder that contains active notes
- **THEN** the system returns 422 `folder_has_notes`

### Requirement: Note REST Serialization
The system SHALL serialize note resources through REST responses with stable JSON fields.

#### Scenario: Note folder REST serialization
- **WHEN** the REST API serializes a note folder
- **THEN** it includes id, name, position, is_default, inserted_at, and updated_at

#### Scenario: Note REST serialization
- **WHEN** the REST API serializes a note
- **THEN** it includes id, folder_id, title, body, pinned, position, deleted_at, inserted_at, and updated_at
- **AND** dates and datetimes are formatted as ISO strings when present
