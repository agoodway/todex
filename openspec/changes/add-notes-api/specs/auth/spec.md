## MODIFIED Requirements

### Requirement: Default List Provisioning
The system SHALL create default todo lists and a default note folder when a user registers successfully.

#### Scenario: Default lists are seeded
- **WHEN** user registration succeeds
- **THEN** the system creates the default lists `Personal`, `Work`, `Fitness`, and `Groceries` for that user
- **AND** marks those lists as default lists
- **AND** assigns their configured icon, color, and position metadata

#### Scenario: Default note folder is seeded
- **WHEN** user registration succeeds
- **THEN** the system creates a default note folder named `Notes` for that user
- **AND** marks the note folder as a default folder
- **AND** assigns position `0`

#### Scenario: Registration transaction fails
- **WHEN** creating the user, default todo lists, default note folder, or auth token fails during registration
- **THEN** the system returns the failure reason
- **AND** does not partially complete the registration transaction
