## MODIFIED Requirements

### Requirement: Task Ownership
The system SHALL keep tasks owner-owned while allowing access through owned lists or shared-list permissions.

#### Scenario: Foreign task without share access
- **WHEN** a user reads, updates, deletes, completes, or reopens a task owned by another user and lacks access to the task's list
- **THEN** the system behaves as if the task was not found

#### Scenario: Shared-list task access
- **WHEN** a user has viewer or editor access to a task's list
- **THEN** the system authorizes task access according to the user's list share role

#### Scenario: Foreign list assignment without editor access
- **WHEN** a user creates or updates a task with a list id they neither own nor can edit through a list share
- **THEN** the system rejects the operation with `list_not_found`

#### Scenario: Invalid list id assignment
- **WHEN** a user creates or updates a task with an invalid or missing list id
- **THEN** the system rejects the operation with `list_not_found` or validation errors as applicable

### Requirement: Task Creation
The system SHALL allow an authenticated owner or shared-list editor to create tasks in an accessible editable list.

#### Scenario: Owner task creation
- **WHEN** an authenticated owner creates a task with a valid title and one of their list ids
- **THEN** the task belongs to that user
- **AND** the task belongs to the specified list
- **AND** the task defaults to `active` status when no status is supplied

#### Scenario: Shared-list editor task creation
- **WHEN** an editor creates a task in a list shared with them
- **THEN** the task belongs to the shared list owner
- **AND** the task belongs to the shared list
- **AND** the task defaults to `active` status when no status is supplied

#### Scenario: Shared-list viewer task creation
- **WHEN** a viewer attempts to create a task in a list shared with them
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: Accepted task attributes
- **WHEN** a client creates a task
- **THEN** the system accepts list id, title, notes, status, due date, completion timestamp, and position
- **AND** ignores unknown fields

### Requirement: Task Update
The system SHALL allow an owner or shared-list editor to update tasks in editable lists.

#### Scenario: Owner task update
- **WHEN** an authenticated owner updates one of their tasks with valid attributes
- **THEN** the system persists changed title, notes, status, due date, completion timestamp, list id, and position fields

#### Scenario: Shared-list editor task update
- **WHEN** an editor updates a task in a list shared with them with valid attributes
- **THEN** the system persists changed title, notes, status, due date, completion timestamp, list id, and position fields

#### Scenario: Shared-list viewer task update
- **WHEN** a viewer attempts to update a task in a list shared with them
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: ISO date parsing
- **WHEN** a client supplies an ISO 8601 date string for `due_date`
- **THEN** the system stores it as a date

#### Scenario: ISO datetime parsing
- **WHEN** a client supplies an ISO 8601 datetime string for `completed_at`
- **THEN** the system stores it as a UTC datetime truncated to seconds

#### Scenario: Missing or invalid task id
- **WHEN** an authenticated user updates a missing, inaccessible, or invalid task id
- **THEN** the system returns `not_found`

### Requirement: Task Retrieval
The system SHALL return tasks owned by the authenticated user and tasks in lists shared with the authenticated user through the appropriate access paths.

#### Scenario: Get owned task
- **WHEN** an authenticated user requests one of their task ids
- **THEN** the system returns that task

#### Scenario: Get shared-list task
- **WHEN** an authenticated viewer or editor requests a task in a list shared with them
- **THEN** the system returns that task

#### Scenario: Get missing or invalid task id
- **WHEN** an authenticated user requests a missing, inaccessible, or invalid task id
- **THEN** the system returns `not_found` or no task

### Requirement: Task Listing
The system SHALL list owned tasks by default and SHALL allow shared-list task listing through shared-list access paths.

#### Scenario: Default task ordering
- **WHEN** an authenticated user lists owned tasks
- **THEN** the system returns only that user's owned tasks
- **AND** orders them by ascending due date, ascending position, and ascending creation time

#### Scenario: Shared-list task listing
- **WHEN** a viewer or editor lists tasks for a list shared with them
- **THEN** the system returns tasks in that shared list

#### Scenario: Today view
- **WHEN** a user lists tasks with `view=today`
- **THEN** the system returns active tasks due today

#### Scenario: Upcoming view
- **WHEN** a user lists tasks with `view=upcoming`
- **THEN** the system returns active tasks due after today

#### Scenario: Completed view
- **WHEN** a user lists tasks with `view=completed`
- **THEN** the system returns completed tasks

#### Scenario: List filter
- **WHEN** a user lists tasks with a valid `list_id`
- **THEN** the system returns tasks in that list when the user owns the list or has share access to it

#### Scenario: Invalid list filter
- **WHEN** a user lists tasks with an invalid or inaccessible `list_id`
- **THEN** the system returns an empty task list

#### Scenario: Status filter
- **WHEN** a user lists tasks with `status=active` or `status=completed`
- **THEN** the system returns tasks with the requested status

#### Scenario: Search filter
- **WHEN** a user lists tasks with a non-empty `q` value
- **THEN** the system returns tasks whose title or notes match the search text case-insensitively

#### Scenario: Date range filters
- **WHEN** a user lists tasks with valid `due_after` or `due_before` dates
- **THEN** the system filters tasks to the inclusive due date range

#### Scenario: Invalid date filters
- **WHEN** a user lists tasks with invalid `due_after` or `due_before` dates
- **THEN** the system returns an empty task list

### Requirement: Task Completion State
The system SHALL provide explicit complete and reopen operations for owners and shared-list editors.

#### Scenario: Owner completes task
- **WHEN** an authenticated owner completes one of their tasks
- **THEN** the system sets status to `completed`
- **AND** sets `completed_at` to the current UTC datetime

#### Scenario: Shared-list editor completes task
- **WHEN** an editor completes a task in a list shared with them
- **THEN** the system sets status to `completed`
- **AND** sets `completed_at` to the current UTC datetime

#### Scenario: Owner reopens task
- **WHEN** an authenticated owner reopens one of their tasks
- **THEN** the system sets status to `active`
- **AND** clears `completed_at`

#### Scenario: Shared-list editor reopens task
- **WHEN** an editor reopens a task in a list shared with them
- **THEN** the system sets status to `active`
- **AND** clears `completed_at`

#### Scenario: Shared-list viewer completes or reopens task
- **WHEN** a viewer attempts to complete or reopen a task in a list shared with them
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: Complete or reopen missing task
- **WHEN** an authenticated user completes or reopens a missing, inaccessible, or invalid task id
- **THEN** the system returns `not_found`

### Requirement: Task Deletion
The system SHALL allow task owners and shared-list editors to delete tasks in editable lists.

#### Scenario: Owner task deletion
- **WHEN** an authenticated owner deletes one of their tasks
- **THEN** the system deletes the task

#### Scenario: Shared-list editor task deletion
- **WHEN** an editor deletes a task in a list shared with them
- **THEN** the system deletes the task

#### Scenario: Shared-list viewer task deletion
- **WHEN** a viewer attempts to delete a task in a list shared with them
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: Delete missing task
- **WHEN** an authenticated user deletes a missing, inaccessible, or invalid task id
- **THEN** the system returns `not_found`
