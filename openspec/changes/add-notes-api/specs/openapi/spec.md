## ADDED Requirements

### Requirement: Note Component Schemas
The system SHALL include OpenAPI schemas for note folders, notes, and note request bodies.

#### Scenario: Note resource schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `NoteFolder` and `Note` schemas
- **AND** timestamp fields use date-time formats where applicable

#### Scenario: Note request schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes request schemas for note folders and notes

### Requirement: Note REST Path Coverage
The system SHALL document all implemented note REST paths.

#### Scenario: Note folder paths
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `/api/note-folders` and `/api/note-folders/{id}` with implemented methods

#### Scenario: Note paths
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `/api/notes`, `/api/notes/{id}`, `/api/notes/{id}/pin`, `/api/notes/{id}/unpin`, `/api/notes/{id}/restore`, and `/api/notes/{id}/permanent` with implemented methods

#### Scenario: Note operation ids
- **WHEN** the OpenAPI document is generated
- **THEN** each note REST operation has a stable operation id matching the implemented API spec

### Requirement: Note OpenAPI Parameters and Responses
The system SHALL document note query parameters and common note error responses.

#### Scenario: Note query parameters
- **WHEN** the OpenAPI document describes `GET /api/notes`
- **THEN** it documents `folder_id`, `q`, `pinned`, and `deleted` query parameters

#### Scenario: Note operation error responses
- **WHEN** the OpenAPI document describes a note REST operation
- **THEN** it includes error responses for 400, 401, 404, 415, and 422
