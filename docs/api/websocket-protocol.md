# Todex WebSocket Protocol

Todex exposes an authenticated WebSocket command API for realtime list, task, note folder, and note mutations.

## Endpoint

```http
GET /api/ws
```

No credentials are passed in the URL. The connection starts unauthenticated. The client must complete the auth handshake (see below) before sending any commands.

## Authentication Handshake

After the WebSocket connection is established, the client must send an auth message as the first message:

```json
{
  "type": "auth",
  "payload": {
    "token": "<jwt>"
  }
}
```

### Success

On a valid, non-revoked JWT the server replies:

```json
{
  "type": "auth_ok"
}
```

The connection is now registered for broadcasts and ready to receive commands.

### Failure

On an invalid or revoked token the server replies:

```json
{
  "id": null,
  "type": "error",
  "error": {
    "code": "unauthorized",
    "message": "Unauthorized",
    "details": {}
  }
}
```

The connection remains unauthenticated. The client may retry the auth message with a fresh token or close the connection.

### Commands Before Auth

Any non-auth message received before a successful auth handshake is rejected with the same unauthorized error envelope shown above. The message is NOT dispatched to the command handler.

## Command Envelope

After successful authentication, clients send JSON command envelopes with a client-chosen `id`, a command `type`, and a command-specific `payload` object.

```json
{
  "id": "client-command-id",
  "type": "task:create",
  "payload": {
    "list_id": "list-uuid",
    "title": "Write WebSocket docs"
  }
}
```

## Success Response

Successful commands return an `ok` envelope with the same command `id` and a serialized record payload.

```json
{
  "id": "client-command-id",
  "type": "ok",
  "payload": {
    "task": {
      "id": "task-uuid",
      "list_id": "list-uuid",
      "title": "Write WebSocket docs",
      "notes": null,
      "status": "active",
      "due_date": null,
      "completed_at": null,
      "position": 0,
      "inserted_at": "2026-05-29T00:00:00",
      "updated_at": "2026-05-29T00:00:00"
    }
  }
}
```

List commands return `payload.list`; task commands return `payload.task`; note folder commands return `payload.note_folder`; note commands return `payload.note`.

## Error Response

Errors return an `error` envelope. Validation errors include field-level details in `error.details`.

```json
{
  "id": "client-command-id",
  "type": "error",
  "error": {
    "code": "validation_failed",
    "message": "Validation failed",
    "details": {
      "title": ["can't be blank"]
    }
  }
}
```

## Supported Commands

- `list:create`
- `list:update`
- `list:delete`
- `task:create`
- `task:update`
- `task:delete`
- `task:complete`
- `task:reopen`
- `note_folder:create`
- `note_folder:update`
- `note_folder:delete`
- `note:create`
- `note:update`
- `note:delete`
- `note:pin`
- `note:unpin`
- `note:restore`
- `note:permanent_delete`

Update, delete, complete, reopen, pin, unpin, restore, and permanent delete commands identify the target record with `payload.id`.

Note commands use this payload shape:

```json
{
  "id": "client-command-id",
  "type": "note:create",
  "payload": {
    "folder_id": "note-folder-uuid",
    "title": "Meeting notes",
    "body": "Markdown or plain text",
    "pinned": false,
    "position": 0
  }
}
```

Note folder commands use `name` and `position` fields. Client-supplied default-folder flags are ignored.

## Broadcast Events

After a successful mutation, Todex broadcasts a per-user event to registered transports.

- `list:created`
- `list:updated`
- `list:deleted`
- `task:created`
- `task:updated`
- `task:deleted`
- `note_folder:created`
- `note_folder:updated`
- `note_folder:deleted`
- `note:created`
- `note:updated`
- `note:deleted`
- `note:restored`
- `note:permanently_deleted`

`task:complete` and `task:reopen` both broadcast `task:updated` with the updated task payload.
`note:pin` and `note:unpin` both broadcast `note:updated` with the updated note payload.

Broadcast messages use this shape:

```json
{
  "type": "task:updated",
  "payload": {
    "task": {
      "id": "task-uuid",
      "status": "completed"
    }
  }
}
```
