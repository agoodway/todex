## ADDED Requirements

### Requirement: Note Realtime Commands
The system SHALL support realtime note folder and note mutation commands.

#### Scenario: Note folder create command
- **WHEN** a client sends `note_folder:create` with valid note folder payload
- **THEN** the system creates the note folder
- **AND** replies with an ok envelope containing `payload.note_folder`
- **AND** broadcasts `note_folder:created`

#### Scenario: Note folder update command
- **WHEN** a client sends `note_folder:update` with `payload.id` and valid note folder payload
- **THEN** the system updates the note folder
- **AND** replies with an ok envelope containing `payload.note_folder`
- **AND** broadcasts `note_folder:updated`

#### Scenario: Note folder delete command
- **WHEN** a client sends `note_folder:delete` with `payload.id`
- **THEN** the system deletes the note folder when allowed
- **AND** replies with an ok envelope containing `payload.note_folder`
- **AND** broadcasts `note_folder:deleted`

#### Scenario: Note create command
- **WHEN** a client sends `note:create` with valid note payload
- **THEN** the system creates the note
- **AND** replies with an ok envelope containing `payload.note`
- **AND** broadcasts `note:created`

#### Scenario: Note update command
- **WHEN** a client sends `note:update` with `payload.id` and valid note payload
- **THEN** the system updates the note
- **AND** replies with an ok envelope containing `payload.note`
- **AND** broadcasts `note:updated`

#### Scenario: Note delete command
- **WHEN** a client sends `note:delete` with `payload.id`
- **THEN** the system soft deletes the note
- **AND** replies with an ok envelope containing `payload.note`
- **AND** broadcasts `note:deleted`

#### Scenario: Note pin command
- **WHEN** a client sends `note:pin` with `payload.id`
- **THEN** the system pins the note
- **AND** replies with an ok envelope containing `payload.note`
- **AND** broadcasts `note:updated`

#### Scenario: Note unpin command
- **WHEN** a client sends `note:unpin` with `payload.id`
- **THEN** the system unpins the note
- **AND** replies with an ok envelope containing `payload.note`
- **AND** broadcasts `note:updated`

#### Scenario: Note restore command
- **WHEN** a client sends `note:restore` with `payload.id`
- **THEN** the system restores the note
- **AND** replies with an ok envelope containing `payload.note`
- **AND** broadcasts `note:restored`

#### Scenario: Note permanent delete command
- **WHEN** a client sends `note:permanent_delete` with `payload.id`
- **THEN** the system permanently deletes the note
- **AND** replies with an ok envelope containing `payload.note`
- **AND** broadcasts `note:permanently_deleted`

### Requirement: Note Realtime Errors
The system SHALL use existing realtime error envelope conventions for note command failures.

#### Scenario: Note validation error response
- **WHEN** a note command fails with validation errors
- **THEN** the system replies with type `error`
- **AND** code `validation_failed`
- **AND** message `Validation failed`
- **AND** field-level details

#### Scenario: Note folder not found error response
- **WHEN** a note command references a note folder that is not found in the user's scope
- **THEN** the system replies with an error envelope whose code is `folder_not_found`

#### Scenario: Note folder has notes error response
- **WHEN** a note folder delete command references a folder with active notes
- **THEN** the system replies with an error envelope whose code is `folder_has_notes`
