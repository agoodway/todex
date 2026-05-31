## ADDED Requirements

### Requirement: Task Goal Progress Side Effects
The system SHALL recompute the progress of every goal a task is linked to whenever that task's completion state or existence changes, scoped to the authenticated user.

#### Scenario: Complete linked task
- **WHEN** an authenticated user completes a task linked to one or more goals
- **THEN** the system recomputes the progress of each linked goal
- **AND** the recompute occurs in the same transaction as the task write

#### Scenario: Reopen linked task
- **WHEN** an authenticated user reopens a task linked to one or more goals
- **THEN** the system recomputes the progress of each linked goal

#### Scenario: Update linked task completion state
- **WHEN** an authenticated user updates a task linked to one or more goals and the update changes its status or completion timestamp
- **THEN** the system recomputes the progress of each linked goal
- **AND** the recompute occurs in the same transaction as the task write

#### Scenario: Delete linked task
- **WHEN** an authenticated user deletes a task linked to one or more goals
- **THEN** the system removes the task's goal associations
- **AND** recomputes the progress of each goal the task was linked to

#### Scenario: Task write affecting no goals
- **WHEN** an authenticated user writes a task that is not linked to any goal
- **THEN** no goal progress is recomputed

#### Scenario: Affected goals surfaced to callers
- **WHEN** a task write recomputes one or more goals
- **THEN** the affected goals are available to the caller for broadcasting
