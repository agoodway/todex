# Todo Tasks Specification

## Purpose

Todex tracks per-user tasks inside lists with status, notes, due dates, completion timestamps, and ordering metadata.

## Requirements

### Requirement: Task Model
The system SHALL persist tasks with ownership, list membership, task content, status, dates, position, and timestamps.

#### Scenario: Task fields
- **WHEN** a task is persisted
- **THEN** it has an id, user id, list id, title, notes, status, due date, completion timestamp, position, inserted timestamp, and updated timestamp

#### Scenario: Required fields
- **WHEN** a task is validated without a user id, list id, or title
- **THEN** validation fails for the missing required fields

#### Scenario: Title length
- **WHEN** a task title is shorter than 1 character or longer than 255 characters
- **THEN** validation fails

#### Scenario: Status values
- **WHEN** a task status is supplied
- **THEN** the status MUST be either `active` or `completed`

### Requirement: Task Ownership
The system SHALL scope all task operations to the authenticated user.

#### Scenario: Foreign task access
- **WHEN** a user reads, updates, deletes, completes, or reopens a task owned by another user
- **THEN** the system behaves as if the task was not found

#### Scenario: Foreign list assignment
- **WHEN** a user creates or updates a task with a list id owned by another user
- **THEN** the system rejects the operation with `list_not_found`

#### Scenario: Invalid list id assignment
- **WHEN** a user creates or updates a task with an invalid or missing list id
- **THEN** the system rejects the operation with `list_not_found` or validation errors as applicable

### Requirement: Task Creation
The system SHALL allow an authenticated user to create tasks in their own lists.

#### Scenario: Successful task creation
- **WHEN** an authenticated user creates a task with a valid title and one of their list ids
- **THEN** the task belongs to that user
- **AND** the task belongs to the specified list
- **AND** the task defaults to `active` status when no status is supplied

#### Scenario: Accepted task attributes
- **WHEN** a client creates a task
- **THEN** the system accepts list id, title, notes, status, due date, completion timestamp, and position
- **AND** ignores unknown fields

### Requirement: Task Update
The system SHALL allow an authenticated user to update their own tasks.

#### Scenario: Successful task update
- **WHEN** an authenticated user updates one of their tasks with valid attributes
- **THEN** the system persists changed title, notes, status, due date, completion timestamp, list id, and position fields

#### Scenario: ISO date parsing
- **WHEN** a client supplies an ISO 8601 date string for `due_date`
- **THEN** the system stores it as a date

#### Scenario: ISO datetime parsing
- **WHEN** a client supplies an ISO 8601 datetime string for `completed_at`
- **THEN** the system stores it as a UTC datetime truncated to seconds

#### Scenario: Missing or invalid task id
- **WHEN** an authenticated user updates a missing, foreign, or invalid task id
- **THEN** the system returns `not_found`

### Requirement: Task Retrieval
The system SHALL return only tasks owned by the authenticated user.

#### Scenario: Get existing task
- **WHEN** an authenticated user requests one of their task ids
- **THEN** the system returns that task

#### Scenario: Get missing or invalid task id
- **WHEN** an authenticated user requests a missing, foreign, or invalid task id
- **THEN** the system returns `not_found` or no task

### Requirement: Task Listing
The system SHALL list tasks for the authenticated user with optional filters.

#### Scenario: Default task ordering
- **WHEN** an authenticated user lists tasks
- **THEN** the system returns only that user's tasks
- **AND** orders them by ascending due date, ascending position, and ascending creation time

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
- **THEN** the system returns tasks in that list

#### Scenario: Invalid list filter
- **WHEN** a user lists tasks with an invalid `list_id`
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
The system SHALL provide explicit complete and reopen operations.

#### Scenario: Complete task
- **WHEN** an authenticated user completes one of their tasks
- **THEN** the system sets status to `completed`
- **AND** sets `completed_at` to the current UTC datetime

#### Scenario: Reopen task
- **WHEN** an authenticated user reopens one of their tasks
- **THEN** the system sets status to `active`
- **AND** clears `completed_at`

#### Scenario: Complete or reopen missing task
- **WHEN** an authenticated user completes or reopens a missing, foreign, or invalid task id
- **THEN** the system returns `not_found`

### Requirement: Task Deletion
The system SHALL allow an authenticated user to delete their own tasks.

#### Scenario: Successful task deletion
- **WHEN** an authenticated user deletes one of their tasks
- **THEN** the system deletes the task

#### Scenario: Delete missing task
- **WHEN** an authenticated user deletes a missing, foreign, or invalid task id
- **THEN** the system returns `not_found`
