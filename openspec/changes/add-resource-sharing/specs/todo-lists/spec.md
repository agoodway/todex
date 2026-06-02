## MODIFIED Requirements

### Requirement: List Retrieval
The system SHALL return owned lists through owned-list views and SHALL allow authorized collaborators to read shared lists through shared-list access paths.

#### Scenario: List all owned lists
- **WHEN** an authenticated user lists their owned lists
- **THEN** the system returns only that user's owned lists
- **AND** orders them by ascending position and then ascending creation time

#### Scenario: Get owned list
- **WHEN** an authenticated user requests one of their owned list ids
- **THEN** the system returns that list

#### Scenario: Get shared list as viewer or editor
- **WHEN** an authenticated user requests a list shared with them as viewer or editor
- **THEN** the system returns that list through shared-list access paths

#### Scenario: Get missing or inaccessible list
- **WHEN** an authenticated user requests a list id they do not own and that is not shared with them, or that does not exist
- **THEN** the system returns `not_found`

### Requirement: List Update
The system SHALL allow an owner or shared-list editor to update list display metadata.

#### Scenario: Owner list update
- **WHEN** an authenticated owner updates one of their lists with valid attributes
- **THEN** the system persists changed name, icon, color, and position fields

#### Scenario: Shared-list editor update
- **WHEN** an editor updates a list shared with them with valid attributes
- **THEN** the system persists changed name, icon, color, and position fields on the owner-owned list

#### Scenario: Shared-list viewer update
- **WHEN** a viewer attempts to update a list shared with them
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: Unknown update fields
- **WHEN** a client supplies fields outside the allowed list attributes
- **THEN** the system ignores those fields

#### Scenario: Client-supplied default flag on update
- **WHEN** a client supplies `is_default` while updating a list
- **THEN** the system ignores the client-supplied default flag

#### Scenario: Update missing or invalid list id
- **WHEN** an authenticated user updates a missing, inaccessible, or invalid list id
- **THEN** the system returns `not_found`

### Requirement: List Deletion
The system SHALL allow only the owner to delete empty lists.

#### Scenario: Owner successful list deletion
- **WHEN** an authenticated owner deletes one of their lists that has no tasks
- **THEN** the system deletes the list

#### Scenario: Delete list with tasks
- **WHEN** an owner deletes a list that still has tasks
- **THEN** the system rejects the deletion with `list_has_tasks`

#### Scenario: Shared-list editor deletion
- **WHEN** an editor attempts to delete a list shared with them
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: Shared-list viewer deletion
- **WHEN** a viewer attempts to delete a list shared with them
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: Delete missing or invalid list id
- **WHEN** an authenticated user deletes a missing, inaccessible, or invalid list id
- **THEN** the system returns `not_found`
