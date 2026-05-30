# OpenAPI Specification

## Purpose

Todex publishes an OpenAPI 3 document that describes the JSON REST API and bearer-token security model.

## Requirements

### Requirement: OpenAPI Document
The system SHALL generate and serve an OpenAPI 3 document for the REST API.

#### Scenario: Document metadata
- **WHEN** the OpenAPI document is generated
- **THEN** it declares OpenAPI version 3.x
- **AND** uses title `Todex API`
- **AND** uses version `1.0.0`
- **AND** declares `/` as the server URL

#### Scenario: OpenAPI endpoint
- **WHEN** a client requests `GET /api/openapi`
- **THEN** the system returns the generated OpenAPI document as JSON

### Requirement: Component Schemas
The system SHALL include schemas for API resources, requests, authentication responses, and errors.

#### Scenario: Resource schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `User`, `List`, and `Task` schemas
- **AND** timestamp fields use date-time formats where applicable

#### Scenario: Request schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes request schemas for registration, login, lists, and tasks

#### Scenario: Response schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes an auth response schema with user and token data
- **AND** includes an error response schema

### Requirement: Security Scheme
The system SHALL document JWT bearer authentication.

#### Scenario: Bearer auth scheme
- **WHEN** the OpenAPI document is generated
- **THEN** it includes a `bearerAuth` security scheme of type `http`
- **AND** the scheme is `bearer`
- **AND** the bearer format is `JWT`

#### Scenario: Public operations
- **WHEN** the OpenAPI document describes register and login operations
- **THEN** those operations do not require bearer authentication

#### Scenario: Protected operations
- **WHEN** the OpenAPI document describes protected operations
- **THEN** those operations require bearer authentication

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

#### Scenario: Operation ids
- **WHEN** the OpenAPI document is generated
- **THEN** each REST operation has a stable operation id matching the implemented API spec

### Requirement: Documented Statuses and Parameters
The system SHALL document common success and error responses and task list query parameters.

#### Scenario: Common error responses
- **WHEN** the OpenAPI document describes a REST operation
- **THEN** it includes error responses for 400, 401, 404, 415, and 422

#### Scenario: Task query parameters
- **WHEN** the OpenAPI document describes `GET /api/tasks`
- **THEN** it documents `view`, `list_id`, `status`, `q`, `due_after`, and `due_before` query parameters
