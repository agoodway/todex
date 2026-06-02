defmodule TodexWeb.OpenApiTest do
  use Todex.DataCase, async: true

  import Plug.Conn
  import Plug.Test

  @opts TodexWeb.Router.init([])

  test "serves an OpenAPI document for the REST API" do
    response =
      :get
      |> conn("/api/openapi")
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    assert %{"openapi" => "3." <> _} = response
    assert %{"paths" => paths} = response
    assert get_in(response, ["servers", Access.at(0), "url"]) == "/"

    assert Map.has_key?(paths, "/api/tasks")
    assert Map.has_key?(paths, "/api/auth/login")
    assert Map.has_key?(paths, "/api/auth/me")
    assert get_in(paths, ["/api/tasks/{id}", "patch", "responses", "200"]) != nil
    assert get_in(paths, ["/api/lists/{id}", "patch", "responses", "200"]) != nil

    assert get_in(response, ["components", "securitySchemes", "bearerAuth", "scheme"]) ==
             "bearer"

    assert get_in(paths, ["/api/tasks", "get", "responses", "200", "content", "application/json"])
    assert get_in(response, ["components", "schemas", "Task", "properties", "title"])
    assert get_in(response, ["components", "schemas", "NoteFolder", "properties", "name"])
    assert get_in(response, ["components", "schemas", "Goal", "properties", "title"])
    assert get_in(response, ["components", "schemas", "GoalRequest", "properties", "reason"])
    assert get_in(response, ["components", "schemas", "Share", "properties", "recipient"])
    assert get_in(response, ["components", "schemas", "SharedList", "properties", "share"])
    assert get_in(response, ["components", "schemas", "SharedNote", "properties", "note"])
    assert get_in(response, ["components", "schemas", "Pagination", "properties", "page_size"])
    assert get_in(response, ["components", "schemas", "ShareCreateRequest", "properties", "role"])

    assert get_in(response, [
             "components",
             "schemas",
             "GoalLinkTaskRequest",
             "properties",
             "task_id",
             "format"
           ]) == "uuid"

    assert get_in(response, [
             "components",
             "schemas",
             "Note",
             "properties",
             "deleted_at",
             "format"
           ]) ==
             "date-time"

    assert get_in(response, [
             "components",
             "schemas",
             "User",
             "properties",
             "inserted_at",
             "format"
           ]) == "date-time"

    assert get_in(response, [
             "components",
             "schemas",
             "List",
             "properties",
             "updated_at",
             "format"
           ]) == "date-time"

    assert get_in(response, [
             "components",
             "schemas",
             "Task",
             "properties",
             "completed_at",
             "format"
           ]) == "date-time"

    assert get_in(response, [
             "components",
             "schemas",
             "Goal",
             "properties",
             "updated_at",
             "format"
           ]) == "date-time"

    assert get_in(paths, ["/api/auth/register", "post", "operationId"]) == "registerUser"
    assert get_in(paths, ["/api/auth/login", "post", "operationId"]) == "loginUser"
    assert get_in(paths, ["/api/auth/logout", "post", "operationId"]) == "logoutUser"
    assert get_in(paths, ["/api/auth/me", "get", "operationId"]) == "getAuthMe"
    assert get_in(paths, ["/api/lists", "get", "operationId"]) == "listLists"
    assert get_in(paths, ["/api/lists", "post", "operationId"]) == "createList"
    assert get_in(paths, ["/api/lists/{id}", "patch", "operationId"]) == "updateList"
    assert get_in(paths, ["/api/lists/{id}", "delete", "operationId"]) == "deleteList"
    assert get_in(paths, ["/api/lists/{id}/shares", "get", "operationId"]) == "listListShares"
    assert get_in(paths, ["/api/lists/{id}/shares", "post", "operationId"]) == "createListShare"

    assert get_in(paths, ["/api/lists/{id}/shares/{share_id}", "patch", "operationId"]) ==
             "updateListShare"

    assert get_in(paths, ["/api/lists/{id}/shares/{share_id}", "delete", "operationId"]) ==
             "deleteListShare"

    assert get_in(paths, ["/api/tasks", "get", "operationId"]) == "listTasks"
    assert get_in(paths, ["/api/tasks", "post", "operationId"]) == "createTask"
    assert get_in(paths, ["/api/tasks/{id}", "get", "operationId"]) == "getTask"
    assert get_in(paths, ["/api/tasks/{id}", "patch", "operationId"]) == "updateTask"
    assert get_in(paths, ["/api/tasks/{id}", "delete", "operationId"]) == "deleteTask"
    assert get_in(paths, ["/api/tasks/{id}/complete", "post", "operationId"]) == "completeTask"
    assert get_in(paths, ["/api/tasks/{id}/reopen", "post", "operationId"]) == "reopenTask"
    assert get_in(paths, ["/api/note-folders", "get", "operationId"]) == "listNoteFolders"
    assert get_in(paths, ["/api/note-folders", "post", "operationId"]) == "createNoteFolder"
    assert get_in(paths, ["/api/note-folders/{id}", "get", "operationId"]) == "getNoteFolder"
    assert get_in(paths, ["/api/note-folders/{id}", "patch", "operationId"]) == "updateNoteFolder"

    assert get_in(paths, ["/api/note-folders/{id}", "delete", "operationId"]) ==
             "deleteNoteFolder"

    assert get_in(paths, ["/api/notes", "get", "operationId"]) == "listNotes"
    assert get_in(paths, ["/api/notes", "post", "operationId"]) == "createNote"
    assert get_in(paths, ["/api/notes/{id}", "get", "operationId"]) == "getNote"
    assert get_in(paths, ["/api/notes/{id}", "patch", "operationId"]) == "updateNote"
    assert get_in(paths, ["/api/notes/{id}", "delete", "operationId"]) == "deleteNote"
    assert get_in(paths, ["/api/notes/{id}/pin", "post", "operationId"]) == "pinNote"
    assert get_in(paths, ["/api/notes/{id}/unpin", "post", "operationId"]) == "unpinNote"
    assert get_in(paths, ["/api/notes/{id}/restore", "post", "operationId"]) == "restoreNote"
    assert get_in(paths, ["/api/notes/{id}/shares", "get", "operationId"]) == "listNoteShares"
    assert get_in(paths, ["/api/notes/{id}/shares", "post", "operationId"]) == "createNoteShare"

    assert get_in(paths, ["/api/notes/{id}/shares/{share_id}", "patch", "operationId"]) ==
             "updateNoteShare"

    assert get_in(paths, ["/api/notes/{id}/shares/{share_id}", "delete", "operationId"]) ==
             "deleteNoteShare"

    assert get_in(paths, ["/api/shared/lists", "get", "operationId"]) == "listSharedLists"
    assert get_in(paths, ["/api/shared/notes", "get", "operationId"]) == "listSharedNotes"

    assert get_in(paths, ["/api/notes/{id}/permanent", "delete", "operationId"]) ==
             "permanentlyDeleteNote"

    assert get_in(paths, ["/api/goals", "get", "operationId"]) == "listGoals"
    assert get_in(paths, ["/api/goals", "post", "operationId"]) == "createGoal"
    assert get_in(paths, ["/api/goals/{id}", "get", "operationId"]) == "getGoal"
    assert get_in(paths, ["/api/goals/{id}", "patch", "operationId"]) == "updateGoal"
    assert get_in(paths, ["/api/goals/{id}", "delete", "operationId"]) == "deleteGoal"
    assert get_in(paths, ["/api/goals/{id}/tasks", "post", "operationId"]) == "linkGoalTask"

    assert get_in(paths, ["/api/goals/{id}/tasks/{task_id}", "delete", "operationId"]) ==
             "unlinkGoalTask"

    assert get_in(paths, ["/api/goals", "get", "security"]) == [%{"bearerAuth" => []}]

    for {path, method} <- [
          {"/api/goals", "get"},
          {"/api/goals", "post"},
          {"/api/goals/{id}", "get"},
          {"/api/goals/{id}", "patch"},
          {"/api/goals/{id}", "delete"},
          {"/api/goals/{id}/tasks", "post"},
          {"/api/goals/{id}/tasks/{task_id}", "delete"}
        ] do
      assert get_in(paths, [path, method, "security"]) == [%{"bearerAuth" => []}]
      assert get_in(paths, [path, method, "responses", "401"])
      assert get_in(paths, [path, method, "responses", "404"])
    end

    assert response_statuses(paths, "/api/auth/register", "post") == [
             "201",
             "400",
             "401",
             "404",
             "415",
             "422"
           ]

    assert response_statuses(paths, "/api/auth/login", "post") == [
             "200",
             "400",
             "401",
             "404",
             "415",
             "422"
           ]

    assert response_statuses(paths, "/api/tasks", "post") == [
             "201",
             "400",
             "401",
             "404",
             "415",
             "422"
           ]

    assert response_statuses(paths, "/api/tasks/{id}", "patch") == [
             "200",
             "400",
             "401",
             "404",
             "415",
             "422"
           ]

    assert response_statuses(paths, "/api/goals", "post") == [
             "201",
             "400",
             "401",
             "404",
             "415",
             "422"
           ]

    assert response_statuses(paths, "/api/goals/{id}/tasks", "post") == [
             "200",
             "400",
             "401",
             "404",
             "415",
             "422"
           ]

    assert response_statuses(paths, "/api/lists/{id}/shares", "post") == [
             "202",
             "400",
             "401",
             "403",
             "404",
             "409",
             "415",
             "422"
           ]

    assert response_statuses(paths, "/api/notes/{id}/shares/{share_id}", "delete") == [
             "200",
             "400",
             "401",
             "403",
             "404",
             "415",
             "422"
           ]

    assert get_in(paths, [
             "/api/auth/login",
             "post",
             "responses",
             "200",
             "content",
             "application/json",
             "schema",
             "properties",
             "data",
             "properties",
             "token",
             "type"
           ]) == "string"

    task_query_params =
      paths
      |> get_in(["/api/tasks", "get", "parameters"])
      |> Enum.map(& &1["name"])
      |> Enum.sort()

    assert task_query_params == ["due_after", "due_before", "list_id", "q", "status", "view"]

    note_query_params =
      paths
      |> get_in(["/api/notes", "get", "parameters"])
      |> Enum.map(& &1["name"])
      |> Enum.sort()

    assert note_query_params == ["deleted", "folder_id", "pinned", "q"]

    shared_list_query_params =
      paths
      |> get_in(["/api/shared/lists", "get", "parameters"])
      |> Enum.map(& &1["name"])
      |> Enum.sort()

    assert shared_list_query_params == ["page", "page_size"]

    shared_note_query_params =
      paths
      |> get_in(["/api/shared/notes", "get", "parameters"])
      |> Enum.map(& &1["name"])
      |> Enum.sort()

    assert shared_note_query_params == ["page", "page_size"]
  end

  defp response_statuses(paths, path, method) do
    paths
    |> get_in([path, method, "responses"])
    |> Map.keys()
    |> Enum.sort()
  end

  defp json_response(conn, status) do
    assert conn.status == status
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    Jason.decode!(conn.resp_body)
  end
end
