# Todo Lists Specification

## Purpose

Todex organizes tasks into per-user lists that carry display metadata and ordering information.

## Requirements

### Requirement: List Model
The system SHALL persist lists with ownership, display metadata, default status, and timestamps.

#### Scenario: List fields
- **WHEN** a list is persisted
- **THEN** it has an id, user id, name, icon, color, position, default flag, inserted timestamp, and updated timestamp

#### Scenario: Required fields
- **WHEN** a list is validated without a user id or name
- **THEN** validation fails for the missing required fields

#### Scenario: Name length
- **WHEN** a list name is shorter than 1 character or longer than 80 characters
- **THEN** validation fails

#### Scenario: Unique names per user
- **WHEN** a user creates or updates a list to a name already used by one of their lists
- **THEN** validation fails with a uniqueness error

### Requirement: List Creation
The system SHALL allow an authenticated user to create custom lists.

#### Scenario: Successful list creation
- **WHEN** an authenticated user creates a list with valid attributes
- **THEN** the list belongs to that user
- **AND** the system persists name, icon, color, and position when supplied
- **AND** the list is not marked as a default list

#### Scenario: Client-supplied default flag on creation
- **WHEN** a client supplies `is_default` while creating a list
- **THEN** the system ignores the client-supplied default flag

### Requirement: List Retrieval
The system SHALL return only lists owned by the authenticated user.

#### Scenario: List all lists
- **WHEN** an authenticated user lists their lists
- **THEN** the system returns only that user's lists
- **AND** orders them by ascending position and then ascending creation time

#### Scenario: Get existing list
- **WHEN** an authenticated user requests one of their list ids
- **THEN** the system returns that list

#### Scenario: Get missing or foreign list
- **WHEN** an authenticated user requests a list id they do not own or that does not exist
- **THEN** the system returns `not_found`

### Requirement: List Update
The system SHALL allow an authenticated user to update list display metadata.

#### Scenario: Successful list update
- **WHEN** an authenticated user updates one of their lists with valid attributes
- **THEN** the system persists changed name, icon, color, and position fields

#### Scenario: Unknown update fields
- **WHEN** a client supplies fields outside the allowed list attributes
- **THEN** the system ignores those fields

#### Scenario: Client-supplied default flag on update
- **WHEN** a client supplies `is_default` while updating a list
- **THEN** the system ignores the client-supplied default flag

#### Scenario: Update missing or invalid list id
- **WHEN** an authenticated user updates a missing, foreign, or invalid list id
- **THEN** the system returns `not_found`

### Requirement: List Deletion
The system SHALL allow an authenticated user to delete empty lists.

#### Scenario: Successful list deletion
- **WHEN** an authenticated user deletes one of their lists that has no tasks
- **THEN** the system deletes the list

#### Scenario: Delete list with tasks
- **WHEN** an authenticated user deletes a list that still has tasks
- **THEN** the system rejects the deletion with `list_has_tasks`

#### Scenario: Delete missing or invalid list id
- **WHEN** an authenticated user deletes a missing, foreign, or invalid list id
- **THEN** the system returns `not_found`
