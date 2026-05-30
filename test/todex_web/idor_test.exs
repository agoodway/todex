defmodule TodexWeb.IdorTest do
  @moduledoc """
  HTTP cross-user IDOR tests: user B cannot access or mutate resources owned by user A.
  Every cross-user attempt must return 404 (contexts scope by user_id).
  """

  use Todex.DataCase, async: true

  import Plug.Conn
  import Plug.Test

  alias Todex.Onboarding
  alias Todex.Notes
  alias Todex.Todos

  @opts TodexWeb.Router.init([])

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  defp register_user(tag) do
    email = "idor-#{tag}-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user, token: token}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    {user, token}
  end

  defp auth_conn(method, path, token) do
    method
    |> conn(path)
    |> put_req_header("authorization", "Bearer #{token}")
  end

  defp json_conn(method, path, body, token) do
    method
    |> conn(path, Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{token}")
  end

  defp json_response(conn, status) do
    assert conn.status == status
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    Jason.decode!(conn.resp_body)
  end

  # ---------------------------------------------------------------------------
  # List IDOR
  # ---------------------------------------------------------------------------

  test "GET /api/lists/:id returns 404 when list belongs to another user" do
    {user_a, _token_a} = register_user("list-get-a")
    {_user_b, token_b} = register_user("list-get-b")

    [list_a | _] = Todos.list_lists(user_a)

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/lists/#{list_a.id}", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "PATCH /api/lists/:id returns 404 when list belongs to another user" do
    {user_a, _token_a} = register_user("list-patch-a")
    {_user_b, token_b} = register_user("list-patch-b")

    [list_a | _] = Todos.list_lists(user_a)

    assert %{"error" => %{"code" => "not_found"}} =
             :patch
             |> json_conn("/api/lists/#{list_a.id}", %{name: "Stolen"}, token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "DELETE /api/lists/:id returns 404 when list belongs to another user" do
    {user_a, _token_a} = register_user("list-delete-a")
    {_user_b, token_b} = register_user("list-delete-b")

    [list_a | _] = Todos.list_lists(user_a)

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/lists/#{list_a.id}", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  # ---------------------------------------------------------------------------
  # Task IDOR
  # ---------------------------------------------------------------------------

  test "GET /api/tasks/:id returns 404 when task belongs to another user" do
    {user_a, _token_a} = register_user("task-get-a")
    {_user_b, token_b} = register_user("task-get-b")

    [list_a | _] = Todos.list_lists(user_a)
    assert {:ok, task_a} = Todos.create_task(user_a, %{title: "Private task", list_id: list_a.id})

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/tasks/#{task_a.id}", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "PATCH /api/tasks/:id returns 404 when task belongs to another user" do
    {user_a, _token_a} = register_user("task-patch-a")
    {_user_b, token_b} = register_user("task-patch-b")

    [list_a | _] = Todos.list_lists(user_a)
    assert {:ok, task_a} = Todos.create_task(user_a, %{title: "Private task", list_id: list_a.id})

    assert %{"error" => %{"code" => "not_found"}} =
             :patch
             |> json_conn("/api/tasks/#{task_a.id}", %{title: "Stolen"}, token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "DELETE /api/tasks/:id returns 404 when task belongs to another user" do
    {user_a, _token_a} = register_user("task-delete-a")
    {_user_b, token_b} = register_user("task-delete-b")

    [list_a | _] = Todos.list_lists(user_a)
    assert {:ok, task_a} = Todos.create_task(user_a, %{title: "Private task", list_id: list_a.id})

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/tasks/#{task_a.id}", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  # ---------------------------------------------------------------------------
  # Cross-user CREATE IDOR (task with A's list_id, note with A's folder_id)
  # ---------------------------------------------------------------------------

  test "POST /api/tasks with user A's list_id using user B's token returns 422 list_not_found" do
    {user_a, _token_a} = register_user("task-create-idor-a")
    {_user_b, token_b} = register_user("task-create-idor-b")

    [list_a | _] = Todos.list_lists(user_a)

    assert %{"error" => %{"code" => "list_not_found"}} =
             :post
             |> json_conn("/api/tasks", %{title: "Stolen task", list_id: list_a.id}, token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)
  end

  test "POST /api/notes with user A's folder_id using user B's token returns 422 folder_not_found" do
    {user_a, _token_a} = register_user("note-create-idor-a")
    {_user_b, token_b} = register_user("note-create-idor-b")

    [folder_a | _] = Notes.list_folders(user_a)

    assert %{"error" => %{"code" => "folder_not_found"}} =
             :post
             |> json_conn("/api/notes", %{title: "Stolen note", folder_id: folder_a.id}, token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)
  end

  # ---------------------------------------------------------------------------
  # HTTP cross-user permanent delete IDOR
  # ---------------------------------------------------------------------------

  test "DELETE /api/notes/:id/permanent returns 404 when note belongs to another user" do
    {user_a, _token_a} = register_user("note-permdel-idor-a")
    {_user_b, token_b} = register_user("note-permdel-idor-b")

    [folder_a | _] = Notes.list_folders(user_a)
    assert {:ok, note_a} = Notes.create_note(user_a, %{folder_id: folder_a.id, title: "Secret"})

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/notes/#{note_a.id}/permanent", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  # ---------------------------------------------------------------------------
  # Note folder IDOR
  # ---------------------------------------------------------------------------

  test "GET /api/note-folders/:id returns 404 when folder belongs to another user" do
    {user_a, _token_a} = register_user("folder-get-a")
    {_user_b, token_b} = register_user("folder-get-b")

    [folder_a | _] = Notes.list_folders(user_a)

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/note-folders/#{folder_a.id}", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "PATCH /api/note-folders/:id returns 404 when folder belongs to another user" do
    {user_a, _token_a} = register_user("folder-patch-a")
    {_user_b, token_b} = register_user("folder-patch-b")

    [folder_a | _] = Notes.list_folders(user_a)

    assert %{"error" => %{"code" => "not_found"}} =
             :patch
             |> json_conn("/api/note-folders/#{folder_a.id}", %{name: "Stolen"}, token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "DELETE /api/note-folders/:id returns 404 when folder belongs to another user" do
    {user_a, _token_a} = register_user("folder-delete-a")
    {_user_b, token_b} = register_user("folder-delete-b")

    [folder_a | _] = Notes.list_folders(user_a)

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/note-folders/#{folder_a.id}", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  # ---------------------------------------------------------------------------
  # Note IDOR
  # ---------------------------------------------------------------------------

  test "GET /api/notes/:id returns 404 when note belongs to another user" do
    {user_a, _token_a} = register_user("note-get-a")
    {_user_b, token_b} = register_user("note-get-b")

    [folder_a | _] = Notes.list_folders(user_a)
    assert {:ok, note_a} = Notes.create_note(user_a, %{folder_id: folder_a.id, title: "Secret"})

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/notes/#{note_a.id}", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "PATCH /api/notes/:id returns 404 when note belongs to another user" do
    {user_a, _token_a} = register_user("note-patch-a")
    {_user_b, token_b} = register_user("note-patch-b")

    [folder_a | _] = Notes.list_folders(user_a)
    assert {:ok, note_a} = Notes.create_note(user_a, %{folder_id: folder_a.id, title: "Secret"})

    assert %{"error" => %{"code" => "not_found"}} =
             :patch
             |> json_conn("/api/notes/#{note_a.id}", %{title: "Stolen"}, token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "DELETE /api/notes/:id returns 404 when note belongs to another user" do
    {user_a, _token_a} = register_user("note-delete-a")
    {_user_b, token_b} = register_user("note-delete-b")

    [folder_a | _] = Notes.list_folders(user_a)
    assert {:ok, note_a} = Notes.create_note(user_a, %{folder_id: folder_a.id, title: "Secret"})

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/notes/#{note_a.id}", token_b)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end
end
