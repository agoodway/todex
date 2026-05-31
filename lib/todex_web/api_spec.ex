defmodule TodexWeb.ApiSpec do
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.Components
  alias OpenApiSpex.Info
  alias OpenApiSpex.MediaType
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Parameter
  alias OpenApiSpex.PathItem
  alias OpenApiSpex.RequestBody
  alias OpenApiSpex.Response
  alias OpenApiSpex.Schema
  alias OpenApiSpex.SecurityScheme
  alias OpenApiSpex.Server
  alias TodexWeb.Schemas

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      info: %Info{title: "Todex API", version: "1.0.0"},
      servers: [%Server{url: "/"}],
      paths: paths(),
      components: %Components{
        schemas: %{
          "User" => Schemas.User.schema(),
          "List" => Schemas.List.schema(),
          "Task" => Schemas.Task.schema(),
          "Goal" => Schemas.Goal.schema(),
          "NoteFolder" => Schemas.NoteFolder.schema(),
          "Note" => Schemas.Note.schema(),
          "AuthResponse" => Schemas.AuthResponse.schema(),
          "ErrorResponse" => Schemas.ErrorResponse.schema(),
          "RegisterRequest" => Schemas.RegisterRequest.schema(),
          "LoginRequest" => Schemas.LoginRequest.schema(),
          "ListRequest" => Schemas.ListRequest.schema(),
          "TaskRequest" => Schemas.TaskRequest.schema(),
          "GoalRequest" => Schemas.GoalRequest.schema(),
          "GoalLinkTaskRequest" => Schemas.GoalLinkTaskRequest.schema(),
          "NoteFolderRequest" => Schemas.NoteFolderRequest.schema(),
          "NoteRequest" => Schemas.NoteRequest.schema()
        },
        securitySchemes: %{
          "bearerAuth" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp paths do
    %{
      "/api/auth/register" => %PathItem{
        post:
          operation(
            "registerUser",
            "Register",
            "Create a user account",
            request(Schemas.RegisterRequest),
            201,
            response("Created", auth_response_schema()),
            false
          )
      },
      "/api/auth/login" => %PathItem{
        post:
          operation(
            "loginUser",
            "Login",
            "Exchange credentials for a JWT",
            request(Schemas.LoginRequest),
            200,
            response("OK", auth_response_schema()),
            false
          )
      },
      "/api/auth/logout" => %PathItem{
        post:
          operation(
            "logoutUser",
            "Logout",
            "Invalidate the current JWT",
            nil,
            200,
            ok(data_object(%{ok: %Schema{type: :boolean}}))
          )
      },
      "/api/auth/me" => %PathItem{
        get:
          operation(
            "getAuthMe",
            "Current user",
            "Return the authenticated user",
            nil,
            200,
            ok(data_object(%{user: Schemas.User}))
          )
      },
      "/api/lists" => %PathItem{
        get:
          operation(
            "listLists",
            "List lists",
            "Return all lists for the authenticated user",
            nil,
            200,
            ok(data_object(%{lists: array(Schemas.List)}))
          ),
        post:
          operation(
            "createList",
            "Create list",
            "Create a list",
            request(Schemas.ListRequest),
            201,
            created(data_object(%{list: Schemas.List}))
          )
      },
      "/api/lists/{id}" => %PathItem{
        parameters: [id_parameter()],
        get:
          operation(
            "getList",
            "Get list",
            "Return a list",
            nil,
            200,
            ok(data_object(%{list: Schemas.List}))
          ),
        patch:
          operation(
            "updateList",
            "Update list",
            "Update a list",
            request(Schemas.ListRequest),
            200,
            ok(data_object(%{list: Schemas.List}))
          ),
        delete:
          operation(
            "deleteList",
            "Delete list",
            "Delete a list",
            nil,
            200,
            ok(data_object(%{list: Schemas.List}))
          )
      },
      "/api/tasks" => %PathItem{
        get:
          operation(
            "listTasks",
            "List tasks",
            "Return tasks for the authenticated user",
            nil,
            200,
            ok(data_object(%{tasks: array(Schemas.Task)})),
            true,
            task_query_parameters()
          ),
        post:
          operation(
            "createTask",
            "Create task",
            "Create a task",
            request(Schemas.TaskRequest),
            201,
            created(data_object(%{task: Schemas.Task}))
          )
      },
      "/api/tasks/{id}" => %PathItem{
        parameters: [id_parameter()],
        get:
          operation(
            "getTask",
            "Get task",
            "Return a task",
            nil,
            200,
            ok(data_object(%{task: Schemas.Task}))
          ),
        patch:
          operation(
            "updateTask",
            "Update task",
            "Update a task",
            request(Schemas.TaskRequest),
            200,
            ok(data_object(%{task: Schemas.Task}))
          ),
        delete:
          operation(
            "deleteTask",
            "Delete task",
            "Delete a task",
            nil,
            200,
            ok(data_object(%{task: Schemas.Task}))
          )
      },
      "/api/tasks/{id}/complete" => %PathItem{
        parameters: [id_parameter()],
        post:
          operation(
            "completeTask",
            "Complete task",
            "Mark a task complete",
            nil,
            200,
            ok(data_object(%{task: Schemas.Task}))
          )
      },
      "/api/tasks/{id}/reopen" => %PathItem{
        parameters: [id_parameter()],
        post:
          operation(
            "reopenTask",
            "Reopen task",
            "Mark a completed task active",
            nil,
            200,
            ok(data_object(%{task: Schemas.Task}))
          )
      },
      "/api/goals" => %PathItem{
        get:
          operation(
            "listGoals",
            "List goals",
            "Return all goals for the authenticated user",
            nil,
            200,
            ok(data_object(%{goals: array(Schemas.Goal)}))
          ),
        post:
          operation(
            "createGoal",
            "Create goal",
            "Create a goal",
            request(Schemas.GoalRequest),
            201,
            created(data_object(%{goal: Schemas.Goal}))
          )
      },
      "/api/goals/{id}" => %PathItem{
        parameters: [id_parameter()],
        get:
          operation(
            "getGoal",
            "Get goal",
            "Return a goal",
            nil,
            200,
            ok(data_object(%{goal: Schemas.Goal}))
          ),
        patch:
          operation(
            "updateGoal",
            "Update goal",
            "Update a goal",
            request(Schemas.GoalRequest),
            200,
            ok(data_object(%{goal: Schemas.Goal}))
          ),
        delete:
          operation(
            "deleteGoal",
            "Delete goal",
            "Delete a goal",
            nil,
            200,
            ok(data_object(%{goal: Schemas.Goal}))
          )
      },
      "/api/goals/{id}/tasks" => %PathItem{
        parameters: [id_parameter()],
        post:
          operation(
            "linkGoalTask",
            "Link goal task",
            "Link a task to a goal",
            request(Schemas.GoalLinkTaskRequest),
            200,
            ok(data_object(%{goal: Schemas.Goal}))
          )
      },
      "/api/goals/{id}/tasks/{task_id}" => %PathItem{
        parameters: [id_parameter(), task_id_parameter()],
        delete:
          operation(
            "unlinkGoalTask",
            "Unlink goal task",
            "Unlink a task from a goal",
            nil,
            200,
            ok(data_object(%{goal: Schemas.Goal}))
          )
      },
      "/api/note-folders" => %PathItem{
        get:
          operation(
            "listNoteFolders",
            "List note folders",
            "Return all note folders for the authenticated user",
            nil,
            200,
            ok(data_object(%{note_folders: array(Schemas.NoteFolder)}))
          ),
        post:
          operation(
            "createNoteFolder",
            "Create note folder",
            "Create a note folder",
            request(Schemas.NoteFolderRequest),
            201,
            created(data_object(%{note_folder: Schemas.NoteFolder}))
          )
      },
      "/api/note-folders/{id}" => %PathItem{
        parameters: [id_parameter()],
        get:
          operation(
            "getNoteFolder",
            "Get note folder",
            "Return a note folder",
            nil,
            200,
            ok(data_object(%{note_folder: Schemas.NoteFolder}))
          ),
        patch:
          operation(
            "updateNoteFolder",
            "Update note folder",
            "Update a note folder",
            request(Schemas.NoteFolderRequest),
            200,
            ok(data_object(%{note_folder: Schemas.NoteFolder}))
          ),
        delete:
          operation(
            "deleteNoteFolder",
            "Delete note folder",
            "Delete a note folder",
            nil,
            200,
            ok(data_object(%{note_folder: Schemas.NoteFolder}))
          )
      },
      "/api/notes" => %PathItem{
        get:
          operation(
            "listNotes",
            "List notes",
            "Return notes for the authenticated user",
            nil,
            200,
            ok(data_object(%{notes: array(Schemas.Note)})),
            true,
            note_query_parameters()
          ),
        post:
          operation(
            "createNote",
            "Create note",
            "Create a note",
            request(Schemas.NoteRequest),
            201,
            created(data_object(%{note: Schemas.Note}))
          )
      },
      "/api/notes/{id}" => %PathItem{
        parameters: [id_parameter()],
        get:
          operation(
            "getNote",
            "Get note",
            "Return a note",
            nil,
            200,
            ok(data_object(%{note: Schemas.Note}))
          ),
        patch:
          operation(
            "updateNote",
            "Update note",
            "Update a note",
            request(Schemas.NoteRequest),
            200,
            ok(data_object(%{note: Schemas.Note}))
          ),
        delete:
          operation(
            "deleteNote",
            "Delete note",
            "Soft delete a note",
            nil,
            200,
            ok(data_object(%{note: Schemas.Note}))
          )
      },
      "/api/notes/{id}/pin" => note_action_path("pinNote", "Pin note", "Pin a note"),
      "/api/notes/{id}/unpin" => note_action_path("unpinNote", "Unpin note", "Unpin a note"),
      "/api/notes/{id}/restore" =>
        note_action_path("restoreNote", "Restore note", "Restore a note"),
      "/api/notes/{id}/permanent" => %PathItem{
        parameters: [id_parameter()],
        delete:
          operation(
            "permanentlyDeleteNote",
            "Permanently delete note",
            "Permanently delete a note",
            nil,
            200,
            ok(data_object(%{note: Schemas.Note}))
          )
      }
    }
  end

  defp note_action_path(operation_id, summary, description) do
    %PathItem{
      parameters: [id_parameter()],
      post:
        operation(
          operation_id,
          summary,
          description,
          nil,
          200,
          ok(data_object(%{note: Schemas.Note}))
        )
    }
  end

  defp operation(
         operation_id,
         summary,
         description,
         request_body,
         success_status,
         success_response,
         secured \\ true,
         parameters \\ []
       ) do
    %Operation{
      tags: ["REST API"],
      operationId: operation_id,
      summary: summary,
      description: description,
      parameters: parameters,
      requestBody: request_body,
      responses: responses(success_status, success_response),
      security: if(secured, do: [%{"bearerAuth" => []}], else: [])
    }
  end

  defp responses(success_status, success_response) do
    %{
      success_status => success_response,
      400 => error_response("Invalid JSON request body"),
      401 => error_response("Unauthorized"),
      404 => error_response("Not found"),
      415 => error_response("Unsupported media type"),
      422 => error_response("Validation failed")
    }
  end

  defp ok(schema), do: response("OK", schema)
  defp created(schema), do: response("Created", schema)

  defp response(description, schema) do
    %Response{description: description, content: json_content(schema)}
  end

  defp error_response(description), do: response(description, Schemas.ErrorResponse)

  defp request(schema) do
    %RequestBody{required: true, content: json_content(schema)}
  end

  defp json_content(schema) do
    %{"application/json" => %MediaType{schema: schema}}
  end

  defp data_object(properties) do
    %Schema{
      type: :object,
      required: [:data],
      properties: %{
        data: %Schema{type: :object, properties: properties}
      }
    }
  end

  defp auth_response_schema do
    data_object(%{user: Schemas.User, token: %Schema{type: :string}})
  end

  defp array(schema), do: %Schema{type: :array, items: schema}

  defp id_parameter do
    %Parameter{
      name: "id",
      in: :path,
      required: true,
      schema: %Schema{type: :string, format: :uuid}
    }
  end

  defp task_id_parameter do
    %Parameter{
      name: "task_id",
      in: :path,
      required: true,
      schema: %Schema{type: :string, format: :uuid}
    }
  end

  defp task_query_parameters do
    [
      %Parameter{name: "view", in: :query, schema: %Schema{type: :string}},
      %Parameter{name: "list_id", in: :query, schema: %Schema{type: :string, format: :uuid}},
      %Parameter{name: "status", in: :query, schema: %Schema{type: :string}},
      %Parameter{name: "q", in: :query, schema: %Schema{type: :string}},
      %Parameter{name: "due_after", in: :query, schema: %Schema{type: :string, format: :date}},
      %Parameter{name: "due_before", in: :query, schema: %Schema{type: :string, format: :date}}
    ]
  end

  defp note_query_parameters do
    [
      %Parameter{name: "folder_id", in: :query, schema: %Schema{type: :string, format: :uuid}},
      %Parameter{name: "q", in: :query, schema: %Schema{type: :string}},
      %Parameter{name: "pinned", in: :query, schema: %Schema{type: :boolean}},
      %Parameter{name: "deleted", in: :query, schema: %Schema{type: :boolean}}
    ]
  end
end
