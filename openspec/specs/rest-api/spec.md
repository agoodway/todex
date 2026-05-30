# REST API Specification

## Purpose

Todex exposes a JSON REST API for authentication, list management, task management, and API discovery.

## Requirements

### Requirement: API Response Envelopes
The system SHALL use consistent JSON envelopes for API responses.

#### Scenario: Successful response
- **WHEN** an API request succeeds
- **THEN** the response body contains a top-level `data` object

#### Scenario: Error response
- **WHEN** an API request fails
- **THEN** the response body contains a top-level `error` object
- **AND** the error object includes `code`, `message`, and `details`

### Requirement: JSON Request Handling
The system SHALL require JSON content types for endpoints that read JSON request bodies.

#### Scenario: Supported JSON media type
- **WHEN** a body-reading endpoint receives `Content-Type: application/json` or a structured JSON media type ending in `+json`
- **THEN** the system parses the JSON body

#### Scenario: Missing or unsupported media type
- **WHEN** a body-reading endpoint receives a missing or unsupported content type
- **THEN** the system returns 415 `unsupported_media_type`

#### Scenario: Malformed JSON body
- **WHEN** a body-reading endpoint receives malformed JSON
- **THEN** the system returns 400 `invalid_json`

### Requirement: Public API Endpoints
The system SHALL expose public endpoints for health, registration, login, OpenAPI, and development Swagger UI.

#### Scenario: Health endpoint
- **WHEN** a client requests `GET /`
- **THEN** the system returns a successful health response

#### Scenario: Register endpoint
- **WHEN** a client sends `POST /api/auth/register` with valid JSON credentials
- **THEN** the system returns 201 with `data.user` and `data.token`

#### Scenario: Login endpoint
- **WHEN** a client sends `POST /api/auth/login` with valid JSON credentials
- **THEN** the system returns 200 with `data.user` and `data.token`

#### Scenario: OpenAPI endpoint
- **WHEN** a client requests `GET /api/openapi`
- **THEN** the system returns the OpenAPI document as JSON

#### Scenario: Swagger UI enabled
- **WHEN** Swagger UI is enabled and a client requests `GET /swaggerui`
- **THEN** the system serves Swagger UI configured to read `/api/openapi`

#### Scenario: Swagger UI disabled
- **WHEN** Swagger UI is disabled and a client requests `GET /swaggerui`
- **THEN** the system returns 404 `not_found`

### Requirement: Protected Account Endpoints
The system SHALL expose protected endpoints for the authenticated user and logout.

#### Scenario: Current user endpoint
- **WHEN** an authenticated client requests `GET /api/auth/me`
- **THEN** the system returns `data.user` for the current token

#### Scenario: Logout endpoint
- **WHEN** an authenticated client sends `POST /api/auth/logout`
- **THEN** the system revokes the current token
- **AND** returns `data.ok` as true

### Requirement: Protected List Endpoints
The system SHALL expose protected list CRUD endpoints.

#### Scenario: List lists endpoint
- **WHEN** an authenticated client requests `GET /api/lists`
- **THEN** the system returns `data.lists`

#### Scenario: Create list endpoint
- **WHEN** an authenticated client sends `POST /api/lists` with a valid JSON list body
- **THEN** the system returns 201 with `data.list`

#### Scenario: Get list endpoint
- **WHEN** an authenticated client requests `GET /api/lists/{id}` for one of their lists
- **THEN** the system returns `data.list`

#### Scenario: Update list endpoint
- **WHEN** an authenticated client sends `PATCH /api/lists/{id}` with a valid JSON list body
- **THEN** the system returns 200 with `data.list`

#### Scenario: Delete list endpoint
- **WHEN** an authenticated client sends `DELETE /api/lists/{id}` for an empty list
- **THEN** the system returns 200 with `data.list` for the deleted list

### Requirement: Protected Task Endpoints
The system SHALL expose protected task CRUD and state-transition endpoints.

#### Scenario: List tasks endpoint
- **WHEN** an authenticated client requests `GET /api/tasks`
- **THEN** the system returns `data.tasks`

#### Scenario: Task query parameters
- **WHEN** an authenticated client requests `GET /api/tasks` with `view`, `list_id`, `status`, `q`, `due_after`, or `due_before`
- **THEN** the system applies the supported task filters

#### Scenario: Create task endpoint
- **WHEN** an authenticated client sends `POST /api/tasks` with a valid JSON task body
- **THEN** the system returns 201 with `data.task`

#### Scenario: Get task endpoint
- **WHEN** an authenticated client requests `GET /api/tasks/{id}` for one of their tasks
- **THEN** the system returns `data.task`

#### Scenario: Update task endpoint
- **WHEN** an authenticated client sends `PATCH /api/tasks/{id}` with a valid JSON task body
- **THEN** the system returns 200 with `data.task`

#### Scenario: Delete task endpoint
- **WHEN** an authenticated client sends `DELETE /api/tasks/{id}` for one of their tasks
- **THEN** the system returns 200 with `data.task` for the deleted task

#### Scenario: Complete task endpoint
- **WHEN** an authenticated client sends `POST /api/tasks/{id}/complete`
- **THEN** the system returns 200 with `data.task` whose status is `completed`

#### Scenario: Reopen task endpoint
- **WHEN** an authenticated client sends `POST /api/tasks/{id}/reopen`
- **THEN** the system returns 200 with `data.task` whose status is `active`

### Requirement: REST Serialization
The system SHALL serialize API resources with stable JSON fields.

#### Scenario: User serialization
- **WHEN** the system serializes a user
- **THEN** it includes id, email, inserted_at, and updated_at
- **AND** it does not include password or password hash fields

#### Scenario: List serialization
- **WHEN** the system serializes a list
- **THEN** it includes id, name, icon, color, position, is_default, inserted_at, and updated_at

#### Scenario: Task serialization
- **WHEN** the system serializes a task
- **THEN** it includes id, list_id, title, notes, status, due_date, completed_at, position, inserted_at, and updated_at
- **AND** dates and datetimes are formatted as ISO strings when present

### Requirement: Not Found Handling
The system SHALL return JSON 404 responses for unmatched routes and missing protected resources.

#### Scenario: Unknown route
- **WHEN** a client requests an unmatched route
- **THEN** the system returns 404 `not_found`

#### Scenario: Missing resource
- **WHEN** a client requests, updates, or deletes a resource that is not found in their scope
- **THEN** the system returns 404 `not_found`
