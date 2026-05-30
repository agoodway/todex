## ADDED Requirements

### Requirement: Note Folder Model
The system SHALL persist note folders with ownership, display ordering, default status, and timestamps.

#### Scenario: Note folder fields
- **WHEN** a note folder is persisted
- **THEN** it has an id, user id, name, position, default flag, inserted timestamp, and updated timestamp

#### Scenario: Note folder required fields
- **WHEN** a note folder is validated without a user id or name
- **THEN** validation fails for the missing required fields

#### Scenario: Note folder name length
- **WHEN** a note folder name is shorter than 1 character or longer than 80 characters
- **THEN** validation fails

#### Scenario: Unique note folder names per user
- **WHEN** a user creates or updates a note folder to a name already used by one of their note folders
- **THEN** validation fails with a uniqueness error

### Requirement: Default Note Folder Provisioning
The system SHALL create a default note folder for each user.

#### Scenario: Default note folder is seeded
- **WHEN** user registration succeeds
- **THEN** the system creates a default note folder named `Notes` for that user
- **AND** marks the folder as a default folder
- **AND** assigns position `0`

### Requirement: Note Folder Creation
The system SHALL allow an authenticated user to create custom note folders.

#### Scenario: Successful note folder creation
- **WHEN** an authenticated user creates a note folder with valid attributes
- **THEN** the folder belongs to that user
- **AND** the system persists name and position when supplied
- **AND** the folder is not marked as a default folder

#### Scenario: Client-supplied default flag on note folder creation
- **WHEN** a client supplies `is_default` while creating a note folder
- **THEN** the system ignores the client-supplied default flag

### Requirement: Note Folder Retrieval
The system SHALL return only note folders owned by the authenticated user.

#### Scenario: List note folders
- **WHEN** an authenticated user lists note folders
- **THEN** the system returns only that user's note folders
- **AND** orders them by ascending position and then ascending creation time

#### Scenario: Get existing note folder
- **WHEN** an authenticated user requests one of their note folder ids
- **THEN** the system returns that note folder

#### Scenario: Get missing or foreign note folder
- **WHEN** an authenticated user requests a note folder id they do not own or that does not exist
- **THEN** the system returns `not_found`

### Requirement: Note Folder Update
The system SHALL allow an authenticated user to update note folder metadata.

#### Scenario: Successful note folder update
- **WHEN** an authenticated user updates one of their note folders with valid attributes
- **THEN** the system persists changed name and position fields

#### Scenario: Unknown note folder update fields
- **WHEN** a client supplies fields outside the allowed note folder attributes
- **THEN** the system ignores those fields

#### Scenario: Client-supplied default flag on note folder update
- **WHEN** a client supplies `is_default` while updating a note folder
- **THEN** the system ignores the client-supplied default flag

#### Scenario: Update missing or invalid note folder id
- **WHEN** an authenticated user updates a missing, foreign, or invalid note folder id
- **THEN** the system returns `not_found`

### Requirement: Note Folder Deletion
The system SHALL allow an authenticated user to delete note folders that contain no active notes.

#### Scenario: Successful note folder deletion
- **WHEN** an authenticated user deletes one of their note folders that has no active notes
- **THEN** the system deletes the note folder

#### Scenario: Delete note folder with active notes
- **WHEN** an authenticated user deletes a note folder that still has non-deleted notes
- **THEN** the system rejects the deletion with `folder_has_notes`

#### Scenario: Delete missing or invalid note folder id
- **WHEN** an authenticated user deletes a missing, foreign, or invalid note folder id
- **THEN** the system returns `not_found`

### Requirement: Note Model
The system SHALL persist notes with ownership, folder membership, content, pinning, soft-delete state, ordering, and timestamps.

#### Scenario: Note fields
- **WHEN** a note is persisted
- **THEN** it has an id, user id, folder id, title, body, pinned flag, position, deleted_at timestamp, inserted timestamp, and updated timestamp

#### Scenario: Note required fields
- **WHEN** a note is validated without a user id, folder id, or title
- **THEN** validation fails for the missing required fields

#### Scenario: Note title length
- **WHEN** a note title is shorter than 1 character or longer than 255 characters
- **THEN** validation fails

#### Scenario: Note body storage
- **WHEN** a note body is supplied
- **THEN** the system stores it as text without parsing or modifying Markdown/plain-text content

### Requirement: Note Ownership
The system SHALL scope all note operations to the authenticated user.

#### Scenario: Foreign note access
- **WHEN** a user reads, updates, deletes, restores, permanently deletes, pins, or unpins a note owned by another user
- **THEN** the system behaves as if the note was not found

#### Scenario: Foreign note folder assignment
- **WHEN** a user creates or updates a note with a folder id owned by another user
- **THEN** the system rejects the operation with `folder_not_found`

#### Scenario: Invalid note folder assignment
- **WHEN** a user creates or updates a note with an invalid or missing folder id
- **THEN** the system rejects the operation with `folder_not_found` or validation errors as applicable

### Requirement: Note Creation
The system SHALL allow an authenticated user to create notes in their own note folders.

#### Scenario: Successful note creation
- **WHEN** an authenticated user creates a note with a valid title and one of their note folder ids
- **THEN** the note belongs to that user
- **AND** the note belongs to the specified note folder
- **AND** the note is not pinned and not deleted by default

#### Scenario: Accepted note attributes
- **WHEN** a client creates a note
- **THEN** the system accepts folder id, title, body, pinned flag, and position
- **AND** ignores unknown fields

### Requirement: Note Update
The system SHALL allow an authenticated user to update their own notes.

#### Scenario: Successful note update
- **WHEN** an authenticated user updates one of their notes with valid attributes
- **THEN** the system persists changed folder id, title, body, pinned flag, and position fields

#### Scenario: Update missing or invalid note id
- **WHEN** an authenticated user updates a missing, foreign, or invalid note id
- **THEN** the system returns `not_found`

### Requirement: Note Retrieval
The system SHALL return only notes owned by the authenticated user.

#### Scenario: Get existing note
- **WHEN** an authenticated user requests one of their note ids
- **THEN** the system returns that note

#### Scenario: Get soft-deleted note
- **WHEN** an authenticated user requests one of their soft-deleted note ids
- **THEN** the system returns that note with its deleted_at timestamp

#### Scenario: Get missing or invalid note id
- **WHEN** an authenticated user requests a missing, foreign, or invalid note id
- **THEN** the system returns `not_found` or no note

### Requirement: Note Listing
The system SHALL list notes for the authenticated user with optional filters.

#### Scenario: Default note ordering
- **WHEN** an authenticated user lists notes without deleted filtering
- **THEN** the system returns only that user's non-deleted notes
- **AND** orders pinned notes before unpinned notes
- **AND** orders notes by descending updated time within pinned groups

#### Scenario: Folder filter
- **WHEN** a user lists notes with a valid `folder_id`
- **THEN** the system returns notes in that folder

#### Scenario: Invalid folder filter
- **WHEN** a user lists notes with an invalid `folder_id`
- **THEN** the system returns an empty note list

#### Scenario: Pinned filter
- **WHEN** a user lists notes with `pinned=true` or `pinned=false`
- **THEN** the system returns notes matching the requested pinned state

#### Scenario: Search filter
- **WHEN** a user lists notes with a non-empty `q` value
- **THEN** the system returns notes whose title or body match the search text case-insensitively

#### Scenario: Deleted filter
- **WHEN** a user lists notes with `deleted=true`
- **THEN** the system returns only soft-deleted notes

#### Scenario: Explicit active filter
- **WHEN** a user lists notes with `deleted=false`
- **THEN** the system returns only non-deleted notes

### Requirement: Note Pinning
The system SHALL provide explicit pin and unpin operations.

#### Scenario: Pin note
- **WHEN** an authenticated user pins one of their notes
- **THEN** the system sets the note pinned flag to true

#### Scenario: Unpin note
- **WHEN** an authenticated user unpins one of their notes
- **THEN** the system sets the note pinned flag to false

#### Scenario: Pin or unpin missing note
- **WHEN** an authenticated user pins or unpins a missing, foreign, or invalid note id
- **THEN** the system returns `not_found`

### Requirement: Note Soft Deletion
The system SHALL soft delete notes by default and support restore and permanent deletion.

#### Scenario: Soft delete note
- **WHEN** an authenticated user deletes one of their notes
- **THEN** the system sets `deleted_at` to the current UTC datetime
- **AND** the note no longer appears in default note list results

#### Scenario: Restore note
- **WHEN** an authenticated user restores one of their soft-deleted notes
- **THEN** the system clears `deleted_at`
- **AND** the note appears in non-deleted note list results

#### Scenario: Permanently delete note
- **WHEN** an authenticated user permanently deletes one of their notes
- **THEN** the system removes the note row

#### Scenario: Delete, restore, or permanently delete missing note
- **WHEN** an authenticated user deletes, restores, or permanently deletes a missing, foreign, or invalid note id
- **THEN** the system returns `not_found`

### Requirement: Note Serialization
The system SHALL serialize note folders and notes with stable JSON fields.

#### Scenario: Note folder serialization
- **WHEN** the system serializes a note folder
- **THEN** it includes id, name, position, is_default, inserted_at, and updated_at

#### Scenario: Note serialization
- **WHEN** the system serializes a note
- **THEN** it includes id, folder_id, title, body, pinned, position, deleted_at, inserted_at, and updated_at
- **AND** dates and datetimes are formatted as ISO strings when present
