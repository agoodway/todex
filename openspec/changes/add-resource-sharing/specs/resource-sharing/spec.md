## ADDED Requirements

### Requirement: Share Model
The system SHALL persist task-list shares and note shares between an owner and a registered recipient with a role of `viewer` or `editor`.

#### Scenario: List share fields
- **WHEN** a list share is persisted
- **THEN** it records the shared list id, owner user id, recipient user id, role, inserted timestamp, and updated timestamp

#### Scenario: Note share fields
- **WHEN** a note share is persisted
- **THEN** it records the shared note id, owner user id, recipient user id, role, inserted timestamp, and updated timestamp

#### Scenario: Supported roles
- **WHEN** a share is created or updated
- **THEN** the role MUST be either `viewer` or `editor`

#### Scenario: Duplicate recipient share
- **WHEN** an owner shares the same list or note with the same recipient more than once
- **THEN** the system rejects the duplicate share with `share_already_exists`

#### Scenario: Self share
- **WHEN** an owner attempts to share a list or note with themselves
- **THEN** the system rejects the operation with `cannot_share_with_self`

#### Scenario: Share cleanup on resource or user deletion
- **WHEN** a shared list or note is deleted, or a share's owner or recipient user is deleted
- **THEN** the system deletes the associated shares

### Requirement: Registered Recipient Resolution
The system SHALL allow shares only with existing registered users resolved by email.

#### Scenario: Existing recipient email
- **WHEN** an owner creates a share with the email of an existing registered user
- **THEN** the system creates the share for that recipient
- **AND** returns a neutral acknowledgment that does not reveal whether the email belongs to a registered user

#### Scenario: Unknown recipient email
- **WHEN** an owner creates a share with an email that does not belong to a registered user
- **THEN** the system returns the same neutral acknowledgment ("if that user exists, the resource has been shared with them")
- **AND** does not create a share
- **AND** does not reveal whether the email belongs to a registered user

#### Scenario: Malformed recipient email
- **WHEN** an owner creates a share with a missing or malformed email
- **THEN** the system rejects the operation with validation errors

### Requirement: Share Management Authorization
The system SHALL allow only the owner of a shared resource to create, list, update, or delete shares for that resource.

#### Scenario: Owner manages shares
- **WHEN** the owner creates, lists, updates, or deletes shares for their list or note
- **THEN** the system permits the operation when the request is valid

#### Scenario: Recipient manages shares
- **WHEN** a recipient attempts to create, list, update, or delete shares for a resource shared with them
- **THEN** the system returns `not_found`

#### Scenario: Foreign user manages shares
- **WHEN** a user who is neither the owner nor a recipient attempts to manage shares for a resource
- **THEN** the system returns `not_found`

#### Scenario: Recipient self-removal
- **WHEN** a recipient (viewer or editor) attempts to remove their own share
- **THEN** the system returns `not_found`
- **AND** only the resource owner can revoke shares in V1

### Requirement: List Share Access
The system SHALL grant shared-list access according to the recipient's role while keeping the list owner-owned.

#### Scenario: List viewer access
- **WHEN** a viewer accesses a shared list
- **THEN** the system allows the viewer to read the list and tasks in that list
- **AND** rejects list or task mutations with `forbidden`

#### Scenario: List editor access
- **WHEN** an editor accesses a shared list
- **THEN** the system allows the editor to read and update list metadata
- **AND** allows the editor to create, update, complete, reopen, and delete tasks in that list
- **AND** rejects deletion of the shared list itself with `forbidden`

#### Scenario: Editor-created shared-list task ownership
- **WHEN** an editor creates a task in a shared list
- **THEN** the new task belongs to the shared list owner
- **AND** the task belongs to the shared list

#### Scenario: Editor-created task after share revocation
- **WHEN** an owner revokes an editor's list share
- **THEN** tasks the editor created in that list remain owned by the list owner
- **AND** are accessible only through the owner's access paths

### Requirement: Note Share Access
The system SHALL grant shared-note access according to the recipient's role while keeping the note owner-owned.

#### Scenario: Note viewer access
- **WHEN** a viewer accesses a shared note
- **THEN** the system allows the viewer to read the note
- **AND** rejects note mutations with `forbidden`

#### Scenario: Note editor access
- **WHEN** an editor accesses a shared note
- **THEN** the system allows the editor to update the note title and body
- **AND** rejects note deletion, permanent deletion, restore, pin, unpin, and folder movement with `forbidden`

### Requirement: Shared Resource Listing
The system SHALL expose dedicated shared-resource views for resources shared with the authenticated user, and clients SHALL be able to use those views as the durable source of truth for shared resource discovery.

#### Scenario: List shared lists
- **WHEN** an authenticated user requests their shared lists
- **THEN** the system returns lists shared with that user
- **AND** includes share role metadata for each returned list
- **AND** excludes lists owned by the authenticated user unless they were also shared through another owner's share

#### Scenario: List shared notes
- **WHEN** an authenticated user requests their shared notes
- **THEN** the system returns notes shared with that user
- **AND** includes share role metadata for each returned note
- **AND** excludes notes owned by the authenticated user unless they were also shared through another owner's share

#### Scenario: Shared resource discovery after reconnect
- **WHEN** a user reconnects after a list or note was shared with them while they were offline
- **THEN** the shared resource appears in the corresponding shared-resource listing response

#### Scenario: Shared resource response shape
- **WHEN** the system returns a shared list or shared note
- **THEN** the response includes the resource data
- **AND** includes share metadata containing the share id, role, owner information, and timestamps

#### Scenario: Paginated shared listings
- **WHEN** a user requests shared lists or shared notes with pagination parameters
- **THEN** the system returns a bounded page of results with pagination metadata
- **AND** applies a default page size when no pagination parameters are supplied

### Requirement: Root Resource Lifecycle Protection
The system SHALL reserve root resource deletion and share management for resource owners.

#### Scenario: Shared-list editor deletes root list
- **WHEN** a shared-list editor attempts to delete the shared list itself
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: Shared-note editor deletes root note
- **WHEN** a shared-note editor attempts to soft-delete or permanently delete the shared note
- **THEN** the system rejects the operation with `forbidden`

#### Scenario: Owner deletes shared resource
- **WHEN** the owner deletes a shared list or note according to existing lifecycle rules
- **THEN** the system deletes the resource for all collaborators
