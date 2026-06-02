## MODIFIED Requirements

### Requirement: Component Schemas
The system SHALL include schemas for API resources, requests, authentication responses, sharing responses, and errors.

#### Scenario: Resource schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `User`, `List`, `Task`, `Note`, `Goal`, and sharing schemas
- **AND** timestamp fields use date-time formats where applicable

#### Scenario: Request schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes request schemas for registration, login, lists, tasks, notes, goals, and share creation/update

#### Scenario: Response schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes an auth response schema with user and token data
- **AND** includes share response schemas
- **AND** includes shared-list and shared-note response schemas
- **AND** includes an error response schema

#### Scenario: Shared resource response schemas
- **WHEN** the OpenAPI document describes shared-list and shared-note responses
- **THEN** the schemas include both resource data and share metadata
- **AND** the share metadata includes role and owner information

### Requirement: REST Path Coverage
The system SHALL document all implemented REST paths.

#### Scenario: Auth paths
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `/api/auth/register`, `/api/auth/login`, `/api/auth/logout`, and `/api/auth/me`

#### Scenario: List paths
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `/api/lists` and `/api/lists/{id}` with implemented methods

#### Scenario: Task paths
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `/api/tasks`, `/api/tasks/{id}`, `/api/tasks/{id}/complete`, and `/api/tasks/{id}/reopen` with implemented methods

#### Scenario: Sharing paths
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `/api/lists/{id}/shares`, `/api/lists/{id}/shares/{share_id}`, `/api/notes/{id}/shares`, `/api/notes/{id}/shares/{share_id}`, `/api/shared/lists`, and `/api/shared/notes` with implemented methods

#### Scenario: Operation ids
- **WHEN** the OpenAPI document is generated
- **THEN** each REST operation has a stable operation id matching the implemented API spec

### Requirement: Documented Statuses and Parameters
The system SHALL document common success and error responses and supported query parameters.

#### Scenario: Common error responses
- **WHEN** the OpenAPI document describes a REST operation
- **THEN** it includes error responses for 400, 401, 403, 404, 409, 415, and 422 as applicable

#### Scenario: Task query parameters
- **WHEN** the OpenAPI document describes `GET /api/tasks`
- **THEN** it documents `view`, `list_id`, `status`, `q`, `due_after`, and `due_before` query parameters

#### Scenario: Share request schemas
- **WHEN** the OpenAPI document describes share creation and update operations
- **THEN** it documents recipient email and role fields for creation
- **AND** role field for update
- **AND** describes the `202` neutral acknowledgment response for share creation

#### Scenario: Shared listing pagination parameters
- **WHEN** the OpenAPI document describes `GET /api/shared/lists` and `GET /api/shared/notes`
- **THEN** it documents the supported pagination query parameters and pagination metadata in the response
