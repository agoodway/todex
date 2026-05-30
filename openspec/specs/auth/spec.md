# Authentication Specification

## Purpose

Todex authenticates API and WebSocket clients with registered user accounts and persisted JWT bearer tokens.

## Requirements

### Requirement: User Registration
The system SHALL create a user account from an email address and password.

#### Scenario: Successful registration
- **WHEN** a client registers with a valid email address and password
- **THEN** the system creates a user
- **AND** normalizes the email by trimming whitespace and lowercasing it
- **AND** hashes the password before persistence
- **AND** returns the created user and a JWT token

#### Scenario: Invalid registration input
- **WHEN** a client registers without an email or password
- **THEN** the system rejects the request with validation errors

#### Scenario: Invalid email format
- **WHEN** a client registers with an email that does not match the email format rules
- **THEN** the system rejects the request with validation errors

#### Scenario: Invalid password length
- **WHEN** a client registers with a password shorter than 8 characters or longer than 72 characters
- **THEN** the system rejects the request with validation errors

#### Scenario: Duplicate email
- **WHEN** a client registers with an email that already belongs to another user
- **THEN** the system rejects the request with a duplicate email validation error

### Requirement: Default List Provisioning
The system SHALL create default lists when a user registers successfully.

#### Scenario: Default lists are seeded
- **WHEN** user registration succeeds
- **THEN** the system creates the default lists `Personal`, `Work`, `Fitness`, and `Groceries` for that user
- **AND** marks those lists as default lists
- **AND** assigns their configured icon, color, and position metadata

#### Scenario: Registration transaction fails
- **WHEN** creating the user, default lists, or auth token fails during registration
- **THEN** the system returns the failure reason
- **AND** does not partially complete the registration transaction

### Requirement: Login
The system SHALL exchange valid credentials for a JWT token.

#### Scenario: Successful login
- **WHEN** a client logs in with a registered email and correct password
- **THEN** the system returns a JWT token
- **AND** the token can be verified to the registered user

#### Scenario: Email normalization on login
- **WHEN** a client logs in with leading or trailing email whitespace or mixed-case email text
- **THEN** the system normalizes the email before credential lookup

#### Scenario: Invalid credentials
- **WHEN** a client logs in with an unknown email, incorrect password, or malformed credential values
- **THEN** the system returns `invalid_credentials`
- **AND** does not reveal whether the email exists

### Requirement: Token Verification
The system SHALL verify JWT bearer tokens against persisted token records.

#### Scenario: Valid token
- **WHEN** the system verifies a signed JWT with a persisted token identifier
- **THEN** it returns the associated user

#### Scenario: Invalid token
- **WHEN** the system verifies a malformed token, unsigned token, token with invalid claims, or token without a persisted token record
- **THEN** it returns `invalid_token`

### Requirement: Logout
The system SHALL revoke the current token on logout.

#### Scenario: Token revocation
- **WHEN** a client logs out with a valid token
- **THEN** the system deletes the persisted token record
- **AND** subsequent verification of that token returns `invalid_token`

#### Scenario: Idempotent logout
- **WHEN** a client logs out with an invalid, malformed, or already revoked token
- **THEN** the system returns success without exposing token validity

### Requirement: Protected Request Authentication
The system SHALL require bearer authentication for protected API routes.

#### Scenario: Missing or invalid bearer token
- **WHEN** a protected endpoint is requested without a valid `Authorization: Bearer <token>` header
- **THEN** the system returns a 401 `unauthorized` error

#### Scenario: Valid bearer token
- **WHEN** a protected endpoint is requested with a valid bearer token
- **THEN** the system assigns the current user and token to the request context
