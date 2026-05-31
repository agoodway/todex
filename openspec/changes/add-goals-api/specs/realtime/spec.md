## ADDED Requirements

### Requirement: Goal Realtime Commands
The system SHALL support realtime goal mutation and task association commands.

#### Scenario: Goal create command
- **WHEN** a client sends `goal:create` with valid goal payload
- **THEN** the system creates the goal
- **AND** replies with an ok envelope containing `payload.goal`
- **AND** broadcasts `goal:created`

#### Scenario: Goal update command
- **WHEN** a client sends `goal:update` with `payload.id` and valid goal payload
- **THEN** the system updates the goal
- **AND** replies with an ok envelope containing `payload.goal`
- **AND** broadcasts `goal:updated`

#### Scenario: Goal delete command
- **WHEN** a client sends `goal:delete` with `payload.id`
- **THEN** the system deletes the goal
- **AND** replies with an ok envelope containing `payload.goal`
- **AND** broadcasts `goal:deleted`

#### Scenario: Goal link task command
- **WHEN** a client sends `goal:link_task` with `payload.id` and `payload.task_id`
- **THEN** the system links the task to the goal
- **AND** replies with an ok envelope containing `payload.goal`
- **AND** broadcasts `goal:updated` for the affected goal

#### Scenario: Goal unlink task command
- **WHEN** a client sends `goal:unlink_task` with `payload.id` and `payload.task_id`
- **THEN** the system removes the association
- **AND** replies with an ok envelope containing `payload.goal`
- **AND** broadcasts `goal:updated` for the affected goal

### Requirement: Goal Progress Broadcast Fan-out
The system SHALL broadcast a `goal:updated` event for every affected goal recomputed as a side effect of a task command, in addition to the command's own broadcast.

#### Scenario: Task command broadcasts affected goals
- **WHEN** a `task:create`, `task:update`, `task:complete`, `task:reopen`, or `task:delete` command affects one or more linked goals
- **THEN** the system broadcasts the command's `task:*` event
- **AND** broadcasts one `goal:updated` event per affected goal

#### Scenario: Task linked to multiple goals
- **WHEN** a task command affects a task linked to multiple goals
- **THEN** the system broadcasts one `goal:updated` event for each affected goal

#### Scenario: Task command affecting no goals
- **WHEN** a task command affects a task linked to no goals
- **THEN** the system broadcasts only the command's `task:*` event

#### Scenario: Multiple broadcasts per command
- **WHEN** a single command produces more than one broadcast event
- **THEN** the system sends each broadcast event to the user's registered transports

#### Scenario: Goal command missing or foreign resource
- **WHEN** a goal command references a missing, foreign, or invalid goal id or task id
- **THEN** the system replies with an error envelope whose code is `not_found`
