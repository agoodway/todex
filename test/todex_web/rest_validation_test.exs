defmodule TodexWeb.RestValidationTest do
  @moduledoc """
  REST endpoint validation failure tests (422), 404 for nonexistent resources,
  and content-type enforcement (415).
  """

  use Todex.DataCase, async: true

  import Plug.Conn
  import Plug.Test

  alias Todex.Onboarding

  @opts TodexWeb.Router.init([])

  defp register_token do
    email = "rest-val-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{token: token}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    token
  end

  defp register_token_and_list_id do
    token = register_token()

    lists_response =
      :get
      |> auth_conn("/api/lists", token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    list_id = lists_response |> get_in(["data", "lists"]) |> hd() |> Map.fetch!("id")
    {token, list_id}
  end

  defp register_token_and_folder_id do
    token = register_token()

    folders_response =
      :get
      |> auth_conn("/api/note-folders", token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    folder_id = folders_response |> get_in(["data", "note_folders"]) |> hd() |> Map.fetch!("id")
    {token, folder_id}
  end

  defp json_conn(method, path, body, token) do
    method
    |> conn(path, Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{token}")
  end

  defp auth_conn(method, path, token) do
    method
    |> conn(path)
    |> put_req_header("authorization", "Bearer #{token}")
  end

  defp json_response(conn, status) do
    assert conn.status == status
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    Jason.decode!(conn.resp_body)
  end

  # ---------------------------------------------------------------------------
  # REST validation failures
  # ---------------------------------------------------------------------------

  test "POST /api/tasks with blank title returns 422 validation_failed with title details" do
    {token, list_id} = register_token_and_list_id()

    response =
      :post
      |> json_conn("/api/tasks", %{title: "", list_id: list_id}, token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(422)

    assert %{"error" => %{"code" => "validation_failed"}} = response
    assert get_in(response, ["error", "details", "title"]) != nil
  end

  test "POST /api/notes with blank title returns 422 validation_failed with title details" do
    {token, folder_id} = register_token_and_folder_id()

    response =
      :post
      |> json_conn("/api/notes", %{title: "", folder_id: folder_id}, token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(422)

    assert %{"error" => %{"code" => "validation_failed"}} = response
    assert get_in(response, ["error", "details", "title"]) != nil
  end

  test "POST /api/lists with blank name returns 422 validation_failed" do
    token = register_token()

    assert %{"error" => %{"code" => "validation_failed"}} =
             :post
             |> json_conn("/api/lists", %{name: ""}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)
  end

  test "POST /api/note-folders with blank name returns 422 validation_failed" do
    token = register_token()

    assert %{"error" => %{"code" => "validation_failed"}} =
             :post
             |> json_conn("/api/note-folders", %{name: ""}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)
  end

  # ---------------------------------------------------------------------------
  # 404 for valid-but-nonexistent UUIDs
  # ---------------------------------------------------------------------------

  test "GET /api/lists/:id with valid nonexistent UUID returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/lists/#{Ecto.UUID.generate()}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "DELETE /api/lists/:id with valid nonexistent UUID returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/lists/#{Ecto.UUID.generate()}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "GET /api/tasks/:id with valid nonexistent UUID returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/tasks/#{Ecto.UUID.generate()}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "DELETE /api/tasks/:id with valid nonexistent UUID returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/tasks/#{Ecto.UUID.generate()}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "GET /api/note-folders/:id with valid nonexistent UUID returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/note-folders/#{Ecto.UUID.generate()}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "DELETE /api/note-folders/:id with valid nonexistent UUID returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/note-folders/#{Ecto.UUID.generate()}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  # ---------------------------------------------------------------------------
  # Note pin/unpin/restore/permanent-delete on nonexistent note -> 404
  # ---------------------------------------------------------------------------

  test "POST /api/notes/:id/pin on nonexistent note returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :post
             |> json_conn("/api/notes/#{Ecto.UUID.generate()}/pin", %{}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "POST /api/notes/:id/unpin on nonexistent note returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :post
             |> json_conn("/api/notes/#{Ecto.UUID.generate()}/unpin", %{}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "POST /api/notes/:id/restore on nonexistent note returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :post
             |> json_conn("/api/notes/#{Ecto.UUID.generate()}/restore", %{}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "DELETE /api/notes/:id/permanent on nonexistent note returns 404" do
    token = register_token()

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/notes/#{Ecto.UUID.generate()}/permanent", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  # ---------------------------------------------------------------------------
  # Content-type enforcement (415) on POST /api/note-folders and /api/notes
  # ---------------------------------------------------------------------------

  test "POST /api/note-folders without Content-Type returns 415" do
    token = register_token()

    response =
      conn(:post, "/api/note-folders", Jason.encode!(%{name: "test"}))
      |> put_req_header("authorization", "Bearer #{token}")
      |> TodexWeb.Router.call(@opts)
      |> json_response(415)

    assert %{"error" => %{"code" => "unsupported_media_type"}} = response
  end

  test "POST /api/notes without Content-Type returns 415" do
    token = register_token()

    response =
      conn(:post, "/api/notes", Jason.encode!(%{title: "test"}))
      |> put_req_header("authorization", "Bearer #{token}")
      |> TodexWeb.Router.call(@opts)
      |> json_response(415)

    assert %{"error" => %{"code" => "unsupported_media_type"}} = response
  end

  # ---------------------------------------------------------------------------
  # Suggestion: whitespace-only search returns all notes (no filter applied)
  # ---------------------------------------------------------------------------

  test "list_notes with whitespace-only q returns all active notes" do
    alias Todex.Notes

    email = "notes-ws-search-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    [folder | _] = Notes.list_folders(user)
    assert {:ok, _n1} = Notes.create_note(user, %{folder_id: folder.id, title: "Alpha"})
    assert {:ok, _n2} = Notes.create_note(user, %{folder_id: folder.id, title: "Beta"})

    results = Notes.list_notes(user, %{q: "   "})
    assert length(results) == 2
  end

  # ---------------------------------------------------------------------------
  # Suggestion: list_notes with deleted: "false" returns only active notes
  # ---------------------------------------------------------------------------

  test "list_notes with deleted: false returns only active notes" do
    alias Todex.Notes

    email = "notes-deleted-filter-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    [folder | _] = Notes.list_folders(user)
    assert {:ok, active_note} = Notes.create_note(user, %{folder_id: folder.id, title: "Active"})

    assert {:ok, deleted_note} =
             Notes.create_note(user, %{folder_id: folder.id, title: "Deleted"})

    assert {:ok, _} = Notes.soft_delete_note(user, deleted_note.id)

    results = Notes.list_notes(user, %{deleted: "false"})
    ids = Enum.map(results, & &1.id)
    assert active_note.id in ids
    refute deleted_note.id in ids
  end

  # ---------------------------------------------------------------------------
  # Suggestion: non-string due_after yields empty results
  # ---------------------------------------------------------------------------

  test "list_tasks with non-string due_after returns empty results" do
    alias Todex.Todos

    email = "tasks-nonstr-date-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    [list | _] = Todos.list_lists(user)

    assert {:ok, _task} =
             Todos.create_task(user, %{
               title: "Has due date",
               list_id: list.id,
               due_date: Date.utc_today()
             })

    # A non-string, non-Date value (integer) should trigger :invalid path -> empty
    assert [] == Todos.list_tasks(user, %{due_after: 12345})
  end
end
