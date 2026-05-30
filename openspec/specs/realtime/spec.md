# Realtime Specification

## Purpose

Todex exposes an authenticated WebSocket command protocol and per-user realtime broadcast registry for list and task mutations.

## Requirements

### Requirement: WebSocket Authentication
The system SHALL authenticate WebSocket clients with the JWT token query parameter.

#### Scenario: Valid join token
- **WHEN** a WebSocket client joins `/api/ws?token=<jwt>` with a valid token
- **THEN** the system registers the socket transport for the token's user
- **AND** replies with a `connected` message

#### Scenario: Invalid join token
- **WHEN** a WebSocket client joins with a missing, invalid, or revoked token
- **THEN** the system unregisters the transport
- **AND** replies with an error envelope whose code is `unauthorized`
- **AND** does not register the transport for broadcasts

#### Scenario: Revoked token on received message
- **WHEN** a registered transport sends a message after its token has been revoked
- **THEN** the system unregisters the transport
- **AND** replies with an `unauthorized` error envelope
- **AND** does not execute the command

### Requirement: Command Envelope
The system SHALL accept WebSocket commands as JSON envelopes with id, type, and payload.

#### Scenario: Valid envelope
- **WHEN** a client sends JSON with `id`, `type`, and object `payload`
- **THEN** the system dispatches the command by type

#### Scenario: Invalid envelope
- **WHEN** a client sends an envelope without a command type or object payload
- **THEN** the system replies with an error envelope whose code is `invalid_envelope`

#### Scenario: Invalid JSON
- **WHEN** a client sends malformed JSON over the WebSocket
- **THEN** the system replies with an error envelope whose code is `invalid_json`

#### Scenario: Unknown command
- **WHEN** a client sends a valid envelope with an unsupported command type
- **THEN** the system replies with an error envelope whose code is `unknown_command`

### Requirement: Supported Commands
The system SHALL support realtime list and task mutation commands.

#### Scenario: List create command
- **WHEN** a client sends `list:create` with valid list payload
- **THEN** the system creates the list
- **AND** replies with an ok envelope containing `payload.list`
- **AND** broadcasts `list:created`

#### Scenario: List update command
- **WHEN** a client sends `list:update` with `payload.id` and valid list payload
- **THEN** the system updates the list
- **AND** replies with an ok envelope containing `payload.list`
- **AND** broadcasts `list:updated`

#### Scenario: List delete command
- **WHEN** a client sends `list:delete` with `payload.id`
- **THEN** the system deletes the list when allowed
- **AND** replies with an ok envelope containing `payload.list`
- **AND** broadcasts `list:deleted`

#### Scenario: Task create command
- **WHEN** a client sends `task:create` with valid task payload
- **THEN** the system creates the task
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:created`

#### Scenario: Task update command
- **WHEN** a client sends `task:update` with `payload.id` and valid task payload
- **THEN** the system updates the task
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:updated`

#### Scenario: Task delete command
- **WHEN** a client sends `task:delete` with `payload.id`
- **THEN** the system deletes the task
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:deleted`

#### Scenario: Task complete command
- **WHEN** a client sends `task:complete` with `payload.id`
- **THEN** the system marks the task completed
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:updated`

#### Scenario: Task reopen command
- **WHEN** a client sends `task:reopen` with `payload.id`
- **THEN** the system marks the task active
- **AND** replies with an ok envelope containing `payload.task`
- **AND** broadcasts `task:updated`

### Requirement: Realtime Response Envelopes
The system SHALL use consistent response envelopes for WebSocket commands.

#### Scenario: Successful command response
- **WHEN** a command succeeds
- **THEN** the system replies with an envelope containing the same command `id`, type `ok`, and serialized record payload

#### Scenario: Validation error response
- **WHEN** a command fails with validation errors
- **THEN** the system replies with type `error`
- **AND** code `validation_failed`
- **AND** message `Validation failed`
- **AND** field-level details

#### Scenario: Domain error response
- **WHEN** a command fails with a known domain error
- **THEN** the system replies with type `error`
- **AND** a code and message derived from the domain error

### Requirement: Per-User Broadcast Registry
The system SHALL maintain a registry of active transports by user and broadcast JSON events to registered transports.

#### Scenario: Register transport
- **WHEN** a transport is registered for a user
- **THEN** subsequent broadcasts for that user are sent to that transport as JSON strings

#### Scenario: Re-register transport
- **WHEN** the same transport is registered for a different or same user
- **THEN** the system removes the previous registration before adding the new one

#### Scenario: Unregister transport for user
- **WHEN** a transport is unregistered for the user currently associated with it
- **THEN** subsequent broadcasts for that user are not sent to that transport

#### Scenario: Unregister transport without user
- **WHEN** a transport is unregistered directly
- **THEN** the system removes that transport from all user registrations

#### Scenario: Transport process exits
- **WHEN** a registered process transport exits
- **THEN** the system removes the transport from the registry

#### Scenario: Socket close
- **WHEN** a WebSocket transport closes
- **THEN** the system unregisters the transport
