## ADDED Requirements

### Requirement: Goal Model
The system SHALL persist goals with ownership, objective content, and a derived progress percentage.

#### Scenario: Goal fields
- **WHEN** a goal is persisted
- **THEN** it has an id, user id, title, description, reason, progress, inserted timestamp, and updated timestamp

#### Scenario: Required fields
- **WHEN** a goal is validated without a user id or title
- **THEN** validation fails for the missing required fields

#### Scenario: Title length
- **WHEN** a goal title is shorter than 1 character or longer than 255 characters
- **THEN** validation fails

#### Scenario: Progress bounds
- **WHEN** a goal is persisted
- **THEN** its progress is an integer between 0 and 100 inclusive
- **AND** progress defaults to 0 when the goal has no linked tasks

### Requirement: Goal Ownership
The system SHALL scope all goal operations to the authenticated user.

#### Scenario: Foreign goal access
- **WHEN** a user reads, updates, or deletes a goal owned by another user
- **THEN** the system behaves as if the goal was not found

#### Scenario: Missing or invalid goal id
- **WHEN** a user reads, updates, or deletes a missing, foreign, or invalid goal id
- **THEN** the system returns `not_found`

### Requirement: Goal Creation
The system SHALL allow an authenticated user to create goals.

#### Scenario: Successful goal creation
- **WHEN** an authenticated user creates a goal with a valid title
- **THEN** the goal belongs to that user
- **AND** the goal has progress 0

#### Scenario: Accepted goal attributes
- **WHEN** a client creates a goal
- **THEN** the system accepts title, description, and reason
- **AND** ignores unknown fields
- **AND** ignores any client-supplied progress value

### Requirement: Goal Update
The system SHALL allow an authenticated user to update their own goals.

#### Scenario: Successful goal update
- **WHEN** an authenticated user updates one of their goals with valid attributes
- **THEN** the system persists changed title, description, and reason fields

#### Scenario: Progress is not directly settable
- **WHEN** a client supplies a progress value on goal update
- **THEN** the system ignores it
- **AND** progress remains derived from the goal's linked tasks

### Requirement: Goal Retrieval
The system SHALL return only goals owned by the authenticated user.

#### Scenario: Get existing goal
- **WHEN** an authenticated user requests one of their goal ids
- **THEN** the system returns that goal with its current progress

#### Scenario: List goals
- **WHEN** an authenticated user lists goals
- **THEN** the system returns only that user's goals

### Requirement: Goal Deletion
The system SHALL allow an authenticated user to delete their own goals without affecting linked tasks.

#### Scenario: Successful goal deletion
- **WHEN** an authenticated user deletes one of their goals
- **THEN** the system deletes the goal
- **AND** removes the goal's task associations
- **AND** leaves the previously linked tasks intact

### Requirement: Goal Task Association
The system SHALL associate tasks and goals through a many-to-many relationship scoped to the owning user.

#### Scenario: Association fields
- **WHEN** a task is linked to a goal
- **THEN** the association records the user id, goal id, and task id

#### Scenario: Many-to-many
- **WHEN** a user links tasks and goals
- **THEN** a task may be linked to many goals
- **AND** a goal may be linked to many tasks

#### Scenario: Unique association
- **WHEN** a user links a task to a goal that is already linked
- **THEN** the system does not create a duplicate association

### Requirement: Link Task To Goal
The system SHALL allow an authenticated user to link one of their tasks to one of their goals.

#### Scenario: Successful link
- **WHEN** an authenticated user links one of their tasks to one of their goals
- **THEN** the system creates the association
- **AND** recomputes the goal's progress
- **AND** returns the updated goal

#### Scenario: Foreign or missing goal or task
- **WHEN** a user links using a missing, foreign, or invalid goal id or task id
- **THEN** the system returns `not_found`

### Requirement: Unlink Task From Goal
The system SHALL allow an authenticated user to unlink one of their tasks from one of their goals.

#### Scenario: Successful unlink
- **WHEN** an authenticated user unlinks one of their tasks from one of their goals
- **THEN** the system removes the association
- **AND** recomputes the goal's progress
- **AND** returns the updated goal

#### Scenario: Unlink missing association
- **WHEN** a user unlinks a task that is not linked to the goal
- **THEN** the system returns `not_found`

### Requirement: Goal Progress Derivation
The system SHALL derive goal progress from the completion state of the goal's linked tasks.

#### Scenario: No linked tasks
- **WHEN** a goal has no linked tasks
- **THEN** its progress is 0

#### Scenario: Partial completion
- **WHEN** a goal has linked tasks and some are completed
- **THEN** its progress equals the completed linked task count divided by the total linked task count, multiplied by 100, rounded to the nearest integer

#### Scenario: Full completion
- **WHEN** every task linked to a goal is completed
- **THEN** its progress is 100

#### Scenario: Recompute on linked task completion change
- **WHEN** a linked task is completed or reopened
- **THEN** the system recomputes the progress of each goal the task is linked to

#### Scenario: Recompute on association change
- **WHEN** a task is linked to or unlinked from a goal
- **THEN** the system recomputes that goal's progress

#### Scenario: Recompute on linked task deletion
- **WHEN** a linked task is deleted
- **THEN** the system removes its associations
- **AND** recomputes the progress of each goal the task was linked to
