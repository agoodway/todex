## ADDED Requirements

### Requirement: Protected Goal Endpoints
The system SHALL expose protected goal CRUD endpoints and task association endpoints.

#### Scenario: List goals endpoint
- **WHEN** an authenticated client requests `GET /api/goals`
- **THEN** the system returns `data.goals`

#### Scenario: Create goal endpoint
- **WHEN** an authenticated client sends `POST /api/goals` with a valid JSON goal body
- **THEN** the system returns 201 with `data.goal`

#### Scenario: Get goal endpoint
- **WHEN** an authenticated client requests `GET /api/goals/{id}` for one of their goals
- **THEN** the system returns `data.goal`

#### Scenario: Update goal endpoint
- **WHEN** an authenticated client sends `PATCH /api/goals/{id}` with a valid JSON goal body
- **THEN** the system returns 200 with `data.goal`

#### Scenario: Goal validation failure
- **WHEN** an authenticated client sends an invalid goal body to a goal create or update endpoint
- **THEN** the system returns the existing validation error envelope

#### Scenario: Delete goal endpoint
- **WHEN** an authenticated client sends `DELETE /api/goals/{id}` for one of their goals
- **THEN** the system returns 200 with `data.goal` for the deleted goal

#### Scenario: Link task endpoint
- **WHEN** an authenticated client sends `POST /api/goals/{id}/tasks` with a JSON body containing `task_id`
- **THEN** the system links the task to the goal
- **AND** returns 200 with `data.goal` whose progress reflects the new association

#### Scenario: Unlink task endpoint
- **WHEN** an authenticated client sends `DELETE /api/goals/{id}/tasks/{task_id}`
- **THEN** the system removes the association
- **AND** returns 200 with `data.goal` whose progress reflects the removed association

#### Scenario: Missing goal or task on association
- **WHEN** an authenticated client links or unlinks using a missing, foreign, or invalid goal id or task id
- **THEN** the system returns 404 `not_found`

#### Scenario: Missing association on unlink
- **WHEN** an authenticated client unlinks an owned task that is not linked to the goal
- **THEN** the system returns 404 `not_found`

### Requirement: Goal Serialization
The system SHALL serialize goals with stable JSON fields.

#### Scenario: Goal serialization
- **WHEN** the system serializes a goal
- **THEN** it includes id, title, description, reason, progress, inserted_at, and updated_at
- **AND** progress is an integer between 0 and 100
