## ADDED Requirements

### Requirement: Shared Resource Broadcast Fanout
The system SHALL broadcast shared resource changes to the owner and all users with active access to the changed resource.

#### Scenario: List share creation notification
- **WHEN** an owner creates a list share for a recipient who has an active realtime connection
- **THEN** the system broadcasts `list:shared` to that recipient
- **AND** the event payload includes the shared list and share metadata

#### Scenario: Note share creation notification
- **WHEN** an owner creates a note share for a recipient who has an active realtime connection
- **THEN** the system broadcasts `note:shared` to that recipient
- **AND** the event payload includes the shared note and share metadata

#### Scenario: Shared list update fanout
- **WHEN** an owner or shared-list editor updates a shared list
- **THEN** the system broadcasts `list:updated` to the owner and all recipients with access to that list

#### Scenario: Shared task mutation fanout
- **WHEN** an owner or shared-list editor creates, updates, deletes, completes, or reopens a task in a shared list
- **THEN** the system broadcasts the corresponding task event to the owner and all recipients with access to that list

#### Scenario: Shared note update fanout
- **WHEN** an owner or shared-note editor updates a shared note
- **THEN** the system broadcasts `note:updated` to the owner and all recipients with access to that note

#### Scenario: Share revocation fanout
- **WHEN** an owner revokes a share
- **THEN** the system broadcasts `list:unshared` (for a list share) or `note:unshared` (for a note share) to the revoked recipient so they can remove the resource from shared views
- **AND** the event payload identifies the resource that was unshared

#### Scenario: Offline recipient share discovery
- **WHEN** an owner creates a list or note share for a recipient who has no active realtime connection
- **THEN** the system does not require realtime delivery
- **AND** the recipient can discover the resource through the shared-resource listing endpoints after reconnecting

#### Scenario: Broadcast recipient de-duplication
- **WHEN** broadcast recipients are resolved for a shared resource event
- **THEN** the system sends at most one event per affected user id

## MODIFIED Requirements

### Requirement: Supported Commands
The system SHALL support realtime list and task mutation commands, applying owner-or-editor access checks for shared lists.

#### Scenario: List create command
- **WHEN** a client sends `list:create` with valid list payload
- **THEN** the system creates the list
- **AND** replies with an ok envelope containing `payload.list`
- **AND** broadcasts `list:created`

#### Scenario: List update command
- **WHEN** a client sends `list:update` with `payload.id` and valid list payload
- **THEN** the system updates the list when the actor owns the list or has editor access
- **AND** replies with an ok envelope containing `payload.list`
- **AND** broadcasts `list:updated`

#### Scenario: List delete command
- **WHEN** a client sends `list:delete` with `payload.id`
- **THEN** the system deletes the list only when the actor owns the list and deletion is allowed
- **AND** replies with an ok envelope containing `payload.list`
- **AND** broadcasts `list:deleted`

#### Scenario: Task create command
- **WHEN** a client sends `task:create` with valid task payload
- **THEN** the system creates the task when the actor owns or can edit the target list
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:created`

#### Scenario: Task update command
- **WHEN** a client sends `task:update` with `payload.id` and valid task payload
- **THEN** the system updates the task when the actor owns or can edit the task's list
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:updated`

#### Scenario: Task delete command
- **WHEN** a client sends `task:delete` with `payload.id`
- **THEN** the system deletes the task when the actor owns or can edit the task's list
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:deleted`

#### Scenario: Task complete command
- **WHEN** a client sends `task:complete` with `payload.id`
- **THEN** the system marks the task completed when the actor owns or can edit the task's list
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:updated`

#### Scenario: Task reopen command
- **WHEN** a client sends `task:reopen` with `payload.id`
- **THEN** the system marks the task active when the actor owns or can edit the task's list
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:updated`
