## ADDED Requirements

### Requirement: Goal OpenAPI Coverage
The system SHALL document goal resources, requests, paths, and operations in the OpenAPI document.

#### Scenario: Goal resource schema
- **WHEN** the OpenAPI document is generated
- **THEN** it includes a `Goal` schema with id, title, description, reason, progress, inserted_at, and updated_at fields
- **AND** timestamp fields use date-time formats where applicable

#### Scenario: Goal request schemas
- **WHEN** the OpenAPI document is generated
- **THEN** it includes request schemas for creating and updating goals
- **AND** includes a request schema for linking a task to a goal

#### Scenario: Goal paths
- **WHEN** the OpenAPI document is generated
- **THEN** it includes `/api/goals` and `/api/goals/{id}` with implemented methods
- **AND** includes `/api/goals/{id}/tasks` and `/api/goals/{id}/tasks/{task_id}` with implemented methods

#### Scenario: Goal operation ids
- **WHEN** the OpenAPI document is generated
- **THEN** each goal REST operation has a stable operation id matching the implemented API spec

#### Scenario: Protected goal operations
- **WHEN** the OpenAPI document describes goal operations
- **THEN** those operations require bearer authentication
- **AND** include error responses for 400, 401, 404, 415, and 422 as applicable
