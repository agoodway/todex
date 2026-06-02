## ADDED Requirements

### Requirement: Protected Sharing Endpoints
The system SHALL expose protected REST endpoints for sharing lists and notes and for listing resources shared with the authenticated user.

#### Scenario: Create list share endpoint
- **WHEN** an owner sends `POST /api/lists/{id}/shares` with a recipient email and valid role
- **THEN** the system returns 202 with a neutral acknowledgment that does not reveal whether the recipient is registered
- **AND** creates the share when the recipient is a registered user

#### Scenario: List list shares endpoint
- **WHEN** an owner requests `GET /api/lists/{id}/shares`
- **THEN** the system returns `data.shares` for that list

#### Scenario: Update list share endpoint
- **WHEN** an owner sends `PATCH /api/lists/{id}/shares/{share_id}` with a valid role
- **THEN** the system returns 200 with `data.share`

#### Scenario: Delete list share endpoint
- **WHEN** an owner sends `DELETE /api/lists/{id}/shares/{share_id}`
- **THEN** the system revokes the share and returns 200 with `data.share`

#### Scenario: Create note share endpoint
- **WHEN** an owner sends `POST /api/notes/{id}/shares` with a recipient email and valid role
- **THEN** the system returns 202 with a neutral acknowledgment that does not reveal whether the recipient is registered
- **AND** creates the share when the recipient is a registered user

#### Scenario: List note shares endpoint
- **WHEN** an owner requests `GET /api/notes/{id}/shares`
- **THEN** the system returns `data.shares` for that note

#### Scenario: Update note share endpoint
- **WHEN** an owner sends `PATCH /api/notes/{id}/shares/{share_id}` with a valid role
- **THEN** the system returns 200 with `data.share`

#### Scenario: Delete note share endpoint
- **WHEN** an owner sends `DELETE /api/notes/{id}/shares/{share_id}`
- **THEN** the system revokes the share and returns 200 with `data.share`

#### Scenario: Shared lists endpoint
- **WHEN** an authenticated client requests `GET /api/shared/lists`
- **THEN** the system returns `data.lists` containing lists shared with that user and share metadata

#### Scenario: Shared notes endpoint
- **WHEN** an authenticated client requests `GET /api/shared/notes`
- **THEN** the system returns `data.notes` containing notes shared with that user and share metadata

#### Scenario: Unauthenticated sharing request
- **WHEN** an unauthenticated client requests any sharing or shared-resource endpoint
- **THEN** the system returns `unauthorized`

### Requirement: Sharing Error Responses
The system SHALL return stable JSON errors for invalid sharing requests.

#### Scenario: Unregistered recipient
- **WHEN** a client attempts to share with an email that does not belong to a registered user
- **THEN** the system returns the neutral 202 acknowledgment and creates no share
- **AND** does not return an error that reveals whether the email is registered

#### Scenario: Duplicate share
- **WHEN** a client attempts to create a duplicate share for the same resource and recipient
- **THEN** the system returns `share_already_exists`

#### Scenario: Self share
- **WHEN** a client attempts to share a resource with themselves
- **THEN** the system returns `cannot_share_with_self`

#### Scenario: Insufficient share permission
- **WHEN** a viewer or editor attempts an operation outside their role permissions
- **THEN** the system returns `forbidden`

## MODIFIED Requirements

### Requirement: REST Serialization
The system SHALL serialize API resources with stable JSON fields.

#### Scenario: User serialization
- **WHEN** the system serializes a user
- **THEN** it includes id, email, inserted_at, and updated_at
- **AND** it does not include password or password hash fields

#### Scenario: List serialization
- **WHEN** the system serializes a list
- **THEN** it includes id, name, icon, color, position, is_default, inserted_at, and updated_at

#### Scenario: Task serialization
- **WHEN** the system serializes a task
- **THEN** it includes id, list_id, title, notes, status, due_date, completed_at, position, inserted_at, and updated_at
- **AND** dates and datetimes are formatted as ISO strings when present

#### Scenario: Share serialization
- **WHEN** the system serializes a share
- **THEN** it includes id, resource id, owner id, recipient user, role, inserted_at, and updated_at

#### Scenario: Shared resource serialization
- **WHEN** the system serializes a shared list or shared note response
- **THEN** it includes the resource fields
- **AND** includes share metadata containing role and owner information
