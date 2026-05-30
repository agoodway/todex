defmodule TodexWeb.WsIdorTest do
  @moduledoc """
  WebSocket cross-user IDOR tests: user B's command handler calls with user A's
  resource IDs must return error envelopes with code "not_found".
  """

  use Todex.DataCase, async: true

  alias Todex.Onboarding
  alias Todex.Notes
  alias Todex.Todos
  alias TodexWeb.Realtime.CommandHandler

  defp register_user(tag) do
    email = "ws-idor-#{tag}-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    user
  end

  test "list:update as user B with user A's list id returns not_found" do
    user_a = register_user("list-update-a")
    user_b = register_user("list-update-b")

    [list_a | _] = Todos.list_lists(user_a)

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-1",
               "type" => "list:update",
               "payload" => %{"id" => list_a.id, "name" => "Stolen"}
             })

    assert response.error.code == "not_found"
  end

  test "task:update as user B with user A's task id returns not_found" do
    user_a = register_user("task-update-a")
    user_b = register_user("task-update-b")

    [list_a | _] = Todos.list_lists(user_a)
    assert {:ok, task_a} = Todos.create_task(user_a, %{title: "Private", list_id: list_a.id})

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-2",
               "type" => "task:update",
               "payload" => %{"id" => task_a.id, "title" => "Stolen"}
             })

    assert response.error.code == "not_found"
  end

  test "task:delete as user B with user A's task id returns not_found" do
    user_a = register_user("task-delete-a")
    user_b = register_user("task-delete-b")

    [list_a | _] = Todos.list_lists(user_a)
    assert {:ok, task_a} = Todos.create_task(user_a, %{title: "Private", list_id: list_a.id})

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-3",
               "type" => "task:delete",
               "payload" => %{"id" => task_a.id}
             })

    assert response.error.code == "not_found"
  end

  test "task:create as user B with user A's list_id returns list_not_found" do
    user_a = register_user("task-create-a")
    user_b = register_user("task-create-b")

    [list_a | _] = Todos.list_lists(user_a)

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-create-task",
               "type" => "task:create",
               "payload" => %{"title" => "Stolen", "list_id" => list_a.id}
             })

    assert response.error.code == "list_not_found"
  end

  test "note:create as user B with user A's folder_id returns folder_not_found" do
    user_a = register_user("note-create-a")
    user_b = register_user("note-create-b")

    [folder_a | _] = Notes.list_folders(user_a)

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-create-note",
               "type" => "note:create",
               "payload" => %{"title" => "Stolen", "folder_id" => folder_a.id}
             })

    assert response.error.code == "folder_not_found"
  end

  test "list:delete as user B with user A's list id returns not_found" do
    user_a = register_user("list-delete-ws-a")
    user_b = register_user("list-delete-ws-b")

    [list_a | _] = Todos.list_lists(user_a)

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-list-delete",
               "type" => "list:delete",
               "payload" => %{"id" => list_a.id}
             })

    assert response.error.code == "not_found"
  end

  test "note_folder:delete as user B with user A's folder id returns not_found" do
    user_a = register_user("folder-delete-ws-a")
    user_b = register_user("folder-delete-ws-b")

    [folder_a | _] = Notes.list_folders(user_a)

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-folder-delete",
               "type" => "note_folder:delete",
               "payload" => %{"id" => folder_a.id}
             })

    assert response.error.code == "not_found"
  end

  test "note_folder:update as user B with user A's folder id returns not_found" do
    user_a = register_user("folder-update-a")
    user_b = register_user("folder-update-b")

    [folder_a | _] = Notes.list_folders(user_a)

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-4",
               "type" => "note_folder:update",
               "payload" => %{"id" => folder_a.id, "name" => "Stolen"}
             })

    assert response.error.code == "not_found"
  end

  test "note:update as user B with user A's note id returns not_found" do
    user_a = register_user("note-update-a")
    user_b = register_user("note-update-b")

    [folder_a | _] = Notes.list_folders(user_a)
    assert {:ok, note_a} = Notes.create_note(user_a, %{folder_id: folder_a.id, title: "Private"})

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-5",
               "type" => "note:update",
               "payload" => %{"id" => note_a.id, "title" => "Stolen"}
             })

    assert response.error.code == "not_found"
  end

  test "note:delete as user B with user A's note id returns not_found" do
    user_a = register_user("note-delete-a")
    user_b = register_user("note-delete-b")

    [folder_a | _] = Notes.list_folders(user_a)
    assert {:ok, note_a} = Notes.create_note(user_a, %{folder_id: folder_a.id, title: "Private"})

    assert {:error, response} =
             CommandHandler.handle(user_b, %{
               "id" => "ws-idor-6",
               "type" => "note:delete",
               "payload" => %{"id" => note_a.id}
             })

    assert response.error.code == "not_found"
  end
end
