defmodule TodexWeb.RestApiTest do
  use Todex.DataCase, async: true

  import Plug.Conn
  import Plug.Test

  @opts TodexWeb.Router.init([])

  test "registers a user and manages lists and tasks through the JSON API" do
    email = "rest-#{System.unique_integer([:positive])}@example.com"

    register_response =
      :post
      |> json_conn("/api/auth/register", %{email: email, password: "super-secret-password"})
      |> TodexWeb.Router.call(@opts)
      |> json_response(201)

    assert %{
             "data" => %{
               "token" => token,
               "user" => %{"email" => ^email}
             }
           } = register_response

    assert is_binary(token)

    lists_response =
      :get
      |> auth_conn("/api/lists", token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    assert %{"data" => %{"lists" => lists}} = lists_response
    assert Enum.map(lists, & &1["name"]) == ["Personal", "Work", "Fitness", "Groceries"]
    [%{"id" => list_id} | _] = lists

    patch_list_response =
      :patch
      |> json_conn("/api/lists/#{list_id}", %{name: "Inbox"}, token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    assert %{"data" => %{"list" => %{"id" => ^list_id, "name" => "Inbox"}}} =
             patch_list_response

    me_response =
      :get
      |> auth_conn("/api/auth/me", token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    assert %{"data" => %{"user" => %{"email" => ^email}}} = me_response

    today = Date.utc_today() |> Date.to_iso8601()

    create_task_response =
      :post
      |> json_conn(
        "/api/tasks",
        %{title: "REST task", list_id: list_id, due_date: today},
        token
      )
      |> TodexWeb.Router.call(@opts)
      |> json_response(201)

    assert %{
             "data" => %{
               "task" => %{"id" => task_id, "title" => "REST task", "status" => "active"}
             }
           } =
             create_task_response

    patch_task_response =
      :patch
      |> json_conn("/api/tasks/#{task_id}", %{title: "Updated REST task"}, token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    assert %{"data" => %{"task" => %{"id" => ^task_id, "title" => "Updated REST task"}}} =
             patch_task_response

    today_response =
      :get
      |> auth_conn("/api/tasks?view=today", token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    assert %{"data" => %{"tasks" => today_tasks}} = today_response
    assert Enum.any?(today_tasks, &(&1["id"] == task_id and &1["title"] == "Updated REST task"))

    complete_response =
      :post
      |> json_conn("/api/tasks/#{task_id}/complete", %{}, token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    assert %{
             "data" => %{
               "task" => %{
                 "id" => ^task_id,
                 "status" => "completed",
                 "completed_at" => completed_at
               }
             }
           } = complete_response

    assert is_binary(completed_at)
  end

  test "manages note folders and notes through the JSON API" do
    {token, folder_id} = registered_token_and_note_folder_id()

    create_folder_response =
      :post
      |> json_conn("/api/note-folders", %{name: "Projects", position: 2}, token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(201)

    assert %{"data" => %{"note_folder" => %{"id" => custom_folder_id, "name" => "Projects"}}} =
             create_folder_response

    update_folder_response =
      :patch
      |> json_conn("/api/note-folders/#{custom_folder_id}", %{name: "Ideas"}, token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(200)

    assert %{"data" => %{"note_folder" => %{"name" => "Ideas"}}} = update_folder_response

    create_note_response =
      :post
      |> json_conn(
        "/api/notes",
        %{folder_id: folder_id, title: "REST note", body: "Alpha body", pinned: true},
        token
      )
      |> TodexWeb.Router.call(@opts)
      |> json_response(201)

    assert %{
             "data" => %{
               "note" => %{
                 "id" => note_id,
                 "folder_id" => ^folder_id,
                 "title" => "REST note",
                 "body" => "Alpha body",
                 "pinned" => true,
                 "deleted_at" => nil
               }
             }
           } = create_note_response

    assert %{"data" => %{"notes" => [%{"id" => ^note_id}]}} =
             :get
             |> auth_conn("/api/notes?q=alpha&pinned=true&folder_id=#{folder_id}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"note" => %{"pinned" => false}}} =
             :post
             |> json_conn("/api/notes/#{note_id}/unpin", %{}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"note" => %{"deleted_at" => deleted_at}}} =
             :delete
             |> auth_conn("/api/notes/#{note_id}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert is_binary(deleted_at)

    assert %{"data" => %{"notes" => [%{"id" => ^note_id}]}} =
             :get
             |> auth_conn("/api/notes?deleted=true", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"note" => %{"deleted_at" => nil}}} =
             :post
             |> json_conn("/api/notes/#{note_id}/restore", %{}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"note" => %{"id" => ^note_id}}} =
             :delete
             |> auth_conn("/api/notes/#{note_id}/permanent", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)
  end

  test "note API returns JSON errors for missing notes, missing folders, and non-empty folders" do
    {token, folder_id} = registered_token_and_note_folder_id()

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/notes/#{Ecto.UUID.generate()}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    assert %{"error" => %{"code" => "folder_not_found"}} =
             :post
             |> json_conn(
               "/api/notes",
               %{folder_id: Ecto.UUID.generate(), title: "Missing folder"},
               token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)

    assert %{"data" => %{"note" => %{"id" => _note_id}}} =
             :post
             |> json_conn("/api/notes", %{folder_id: folder_id, title: "Blocks delete"}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert %{"error" => %{"code" => "folder_has_notes"}} =
             :delete
             |> auth_conn("/api/note-folders/#{folder_id}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)
  end

  test "manages list shares and shared list access through the JSON API" do
    {owner_email, owner_token} = registered_user("list-share-owner")
    {recipient_email, recipient_token} = registered_user("list-share-recipient")
    {_stranger_email, stranger_token} = registered_user("list-share-stranger")
    list_id = first_list_id(owner_token)

    assert %{"data" => %{"message" => message}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: recipient_email, role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(202)

    assert message =~ "resource has been shared"

    assert %{"error" => %{"code" => "share_already_exists"}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: recipient_email, role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(409)

    assert %{"data" => %{"shares" => [share]}} =
             :get
             |> auth_conn("/api/lists/#{list_id}/shares", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{
             "id" => share_id,
             "list_id" => ^list_id,
             "owner_id" => _owner_id,
             "recipient" => %{"email" => ^recipient_email},
             "role" => "viewer"
           } = share

    assert %{"error" => %{"code" => "forbidden"}} =
             :patch
             |> json_conn("/api/lists/#{list_id}", %{name: "Nope"}, recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(403)

    assert %{"data" => %{"share" => %{"role" => "editor"}}} =
             :patch
             |> json_conn(
               "/api/lists/#{list_id}/shares/#{share_id}",
               %{role: "editor"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"list" => %{"name" => "Shared edit"}}} =
             :patch
             |> json_conn("/api/lists/#{list_id}", %{name: "Shared edit"}, recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"error" => %{"code" => "forbidden"}} =
             :delete
             |> auth_conn("/api/lists/#{list_id}", recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(403)

    assert %{
             "data" => %{
               "lists" => [
                 %{
                   "list" => %{"id" => ^list_id, "name" => "Shared edit"},
                   "share" => %{"role" => "editor", "owner" => %{"email" => ^owner_email}}
                 }
               ],
               "pagination" => %{"page" => 1, "page_size" => 20, "total" => 1}
             }
           } =
             :get
             |> auth_conn("/api/shared/lists", recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/lists/#{list_id}/shares", recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/lists/#{list_id}/shares", stranger_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    assert %{"data" => %{"share" => %{"id" => ^share_id}}} =
             :delete
             |> auth_conn("/api/lists/#{list_id}/shares/#{share_id}", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"lists" => []}} =
             :get
             |> auth_conn("/api/shared/lists", recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)
  end

  test "manages note shares and shared note access through the JSON API" do
    {owner_email, owner_token} = registered_user("note-share-owner")
    {recipient_email, recipient_token} = registered_user("note-share-recipient")
    {_stranger_email, stranger_token} = registered_user("note-share-stranger")
    folder_id = first_note_folder_id(owner_token)

    assert %{"data" => %{"note" => %{"id" => note_id}}} =
             :post
             |> json_conn(
               "/api/notes",
               %{folder_id: folder_id, title: "Shared REST note", body: "Before"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert %{"data" => %{"message" => _message}} =
             :post
             |> json_conn(
               "/api/notes/#{note_id}/shares",
               %{recipient_email: recipient_email, role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(202)

    assert %{"data" => %{"shares" => [%{"id" => share_id, "role" => "viewer"}]}} =
             :get
             |> auth_conn("/api/notes/#{note_id}/shares", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"note" => %{"id" => ^note_id}}} =
             :get
             |> auth_conn("/api/notes/#{note_id}", recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"error" => %{"code" => "forbidden"}} =
             :patch
             |> json_conn("/api/notes/#{note_id}", %{title: "Nope"}, recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(403)

    assert %{"data" => %{"share" => %{"role" => "editor"}}} =
             :patch
             |> json_conn(
               "/api/notes/#{note_id}/shares/#{share_id}",
               %{role: "editor"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"note" => %{"title" => "Edited", "body" => "After"}}} =
             :patch
             |> json_conn(
               "/api/notes/#{note_id}",
               %{title: "Edited", body: "After"},
               recipient_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"error" => %{"code" => "forbidden"}} =
             :delete
             |> auth_conn("/api/notes/#{note_id}", recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(403)

    assert %{
             "data" => %{
               "notes" => [
                 %{
                   "note" => %{"id" => ^note_id, "title" => "Edited"},
                   "share" => %{"role" => "editor", "owner" => %{"email" => ^owner_email}}
                 }
               ],
               "pagination" => %{"page" => 1, "page_size" => 50, "total" => 1}
             }
           } =
             :get
             |> auth_conn("/api/shared/notes?page=1&page_size=50", recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/notes/#{note_id}/shares", recipient_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/notes/#{note_id}/shares", stranger_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "share creation and revocation broadcast realtime discovery events" do
    {owner_email, owner_token} = registered_user("share-realtime-owner")
    {recipient_email, recipient_token} = registered_user("share-realtime-recipient")
    recipient_id = user_id(recipient_token)
    list_id = first_list_id(owner_token)

    recipient_transport = forwarding_transport(self(), :recipient)
    assert :ok = Todex.Realtime.register(recipient_id, recipient_transport)

    assert %{"data" => %{"message" => _message}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: recipient_email, role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(202)

    assert_receive {:recipient, shared_payload}

    assert %{
             "type" => "list:shared",
             "payload" => %{
               "list" => %{"id" => ^list_id},
               "share" => %{"role" => "viewer", "owner" => %{"email" => ^owner_email}}
             }
           } = Jason.decode!(shared_payload)

    assert %{"data" => %{"shares" => [%{"id" => share_id}]}} =
             :get
             |> auth_conn("/api/lists/#{list_id}/shares", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"share" => %{"role" => "editor"}}} =
             :patch
             |> json_conn(
               "/api/lists/#{list_id}/shares/#{share_id}",
               %{role: "editor"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert_receive {:recipient, role_updated_payload}

    assert %{
             "type" => "list:shared",
             "payload" => %{
               "list" => %{"id" => ^list_id},
               "share" => %{"role" => "editor", "owner" => %{"email" => ^owner_email}}
             }
           } = Jason.decode!(role_updated_payload)

    assert %{"data" => %{"share" => %{"id" => ^share_id}}} =
             :delete
             |> auth_conn("/api/lists/#{list_id}/shares/#{share_id}", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert_receive {:recipient, unshared_payload}

    assert %{
             "type" => "list:unshared",
             "payload" => %{"list_id" => ^list_id, "share_id" => ^share_id}
           } = Jason.decode!(unshared_payload)

    folder_id = first_note_folder_id(owner_token)

    assert %{"data" => %{"note" => %{"id" => note_id}}} =
             :post
             |> json_conn(
               "/api/notes",
               %{folder_id: folder_id, title: "Realtime shared note"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert %{"data" => %{"message" => _message}} =
             :post
             |> json_conn(
               "/api/notes/#{note_id}/shares",
               %{recipient_email: recipient_email, role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(202)

    assert_receive {:recipient, note_shared_payload}

    assert %{
             "type" => "note:shared",
             "payload" => %{
               "note" => %{"id" => ^note_id},
               "share" => %{"role" => "viewer", "owner" => %{"email" => ^owner_email}}
             }
           } = Jason.decode!(note_shared_payload)

    assert %{"data" => %{"shares" => [%{"id" => note_share_id}]}} =
             :get
             |> auth_conn("/api/notes/#{note_id}/shares", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"share" => %{"role" => "editor"}}} =
             :patch
             |> json_conn(
               "/api/notes/#{note_id}/shares/#{note_share_id}",
               %{role: "editor"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert_receive {:recipient, note_role_updated_payload}

    assert %{
             "type" => "note:shared",
             "payload" => %{
               "note" => %{"id" => ^note_id},
               "share" => %{"role" => "editor", "owner" => %{"email" => ^owner_email}}
             }
           } = Jason.decode!(note_role_updated_payload)

    assert %{"data" => %{"share" => %{"id" => ^note_share_id}}} =
             :delete
             |> auth_conn("/api/notes/#{note_id}/shares/#{note_share_id}", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert_receive {:recipient, note_unshared_payload}

    assert %{
             "type" => "note:unshared",
             "payload" => %{"note_id" => ^note_id, "share_id" => ^note_share_id}
           } = Jason.decode!(note_unshared_payload)

    assert :ok = Todex.Realtime.unregister(recipient_id, recipient_transport)
  end

  test "share creation validates request bodies and keeps unknown recipients neutral" do
    {_owner_email, owner_token} = registered_user("share-validation-owner")
    list_id = first_list_id(owner_token)

    assert %{"error" => %{"code" => "validation_failed", "details" => %{"role" => _}}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: "missing@example.com", role: "admin"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)

    assert %{"error" => %{"code" => "validation_failed", "details" => %{"recipient_email" => _}}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: "not-email", role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)

    assert %{"data" => %{"message" => _message}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: "unknown@example.com", role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(202)

    assert %{"data" => %{"shares" => []}} =
             :get
             |> auth_conn("/api/lists/#{list_id}/shares", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)
  end

  test "share endpoints reject invalid identifiers, self shares, invalid roles, and non-owners" do
    {owner_email, owner_token} = registered_user("share-boundary-owner")
    {recipient_email, recipient_token} = registered_user("share-boundary-recipient")
    list_id = first_list_id(owner_token)

    # Invalid UUID in the list id resolves to a not-found owner lookup.
    assert %{"error" => %{"code" => "not_found"}} =
             :post
             |> json_conn(
               "/api/lists/not-a-uuid/shares",
               %{recipient_email: recipient_email, role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    # Owners cannot share a resource with themselves.
    assert %{"error" => %{"code" => "cannot_share_with_self"}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: owner_email, role: "viewer"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)

    assert %{"data" => %{"message" => _}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: recipient_email, role: "editor"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(202)

    assert %{"data" => %{"shares" => [%{"id" => share_id}]}} =
             :get
             |> auth_conn("/api/lists/#{list_id}/shares", owner_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    # Updating a share with an unsupported role fails validation.
    assert %{"error" => %{"code" => "validation_failed", "details" => %{"role" => _}}} =
             :patch
             |> json_conn(
               "/api/lists/#{list_id}/shares/#{share_id}",
               %{role: "admin"},
               owner_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)

    # An editor recipient is not the owner, so re-sharing is hidden as not-found.
    assert %{"error" => %{"code" => "not_found"}} =
             :post
             |> json_conn(
               "/api/lists/#{list_id}/shares",
               %{recipient_email: "third-party@example.com", role: "viewer"},
               recipient_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)
  end

  test "manages goals and task links through the JSON API" do
    {token, list_id} = registered_token_and_list_id()

    assert %{"data" => %{"goal" => %{"id" => goal_id, "progress" => 0}}} =
             :post
             |> json_conn(
               "/api/goals",
               %{title: "Launch", description: "Ship", reason: "Momentum", progress: 99},
               token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert %{"data" => %{"goals" => [%{"id" => ^goal_id}]}} =
             :get
             |> auth_conn("/api/goals", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"task" => %{"id" => task_id}}} =
             :post
             |> json_conn(
               "/api/tasks",
               %{title: "Done", list_id: list_id, status: "completed"},
               token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert %{"data" => %{"goal" => %{"id" => ^goal_id, "progress" => 100}}} =
             :post
             |> json_conn("/api/goals/#{goal_id}/tasks", %{task_id: task_id}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"goal" => %{"id" => ^goal_id, "title" => "Updated"}}} =
             :patch
             |> json_conn("/api/goals/#{goal_id}", %{title: "Updated", progress: 1}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"goal" => %{"id" => ^goal_id, "progress" => 100}}} =
             :patch
             |> json_conn("/api/goals/#{goal_id}", %{progress: 1}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"data" => %{"goal" => %{"id" => ^goal_id, "progress" => 0}}} =
             :delete
             |> auth_conn("/api/goals/#{goal_id}/tasks/#{task_id}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)

    assert %{"error" => %{"code" => "not_found"}} =
             :delete
             |> auth_conn("/api/goals/#{goal_id}/tasks/#{task_id}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    assert %{"data" => %{"goal" => %{"id" => ^goal_id}}} =
             :delete
             |> auth_conn("/api/goals/#{goal_id}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(200)
  end

  test "goal API returns validation, IDOR, JSON, content-type, and serialization errors" do
    {token, list_id} = registered_token_and_list_id()
    {other_token, other_list_id} = registered_token_and_list_id()

    assert %{"error" => %{"code" => "validation_failed", "details" => %{"title" => _}}} =
             :post
             |> json_conn("/api/goals", %{title: ""}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(422)

    assert %{"data" => %{"goal" => goal}} =
             :post
             |> json_conn(
               "/api/goals",
               %{title: "Goal", description: "Desc", reason: "Why"},
               token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert Map.keys(goal) |> Enum.sort() == [
             "description",
             "id",
             "inserted_at",
             "progress",
             "reason",
             "title",
             "updated_at"
           ]

    assert is_integer(goal["progress"])
    assert is_binary(goal["inserted_at"])
    assert is_binary(goal["updated_at"])

    assert %{"data" => %{"goal" => %{"id" => other_goal_id}}} =
             :post
             |> json_conn("/api/goals", %{title: "Other goal"}, other_token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert %{"data" => %{"task" => %{"id" => other_task_id}}} =
             :post
             |> json_conn(
               "/api/tasks",
               %{title: "Other task", list_id: other_list_id},
               other_token
             )
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert %{"data" => %{"task" => %{"id" => task_id}}} =
             :post
             |> json_conn("/api/tasks", %{title: "Owned task", list_id: list_id}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert %{"error" => %{"code" => "not_found"}} =
             :get
             |> auth_conn("/api/goals/#{other_goal_id}", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    assert %{"error" => %{"code" => "not_found"}} =
             :post
             |> json_conn("/api/goals/#{goal["id"]}/tasks", %{task_id: other_task_id}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    assert %{"error" => %{"code" => "not_found"}} =
             :post
             |> json_conn("/api/goals/#{other_goal_id}/tasks", %{task_id: task_id}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(404)

    malformed_response =
      conn(:post, "/api/goals", "{")
      |> put_req_header("content-type", "application/json")
      |> maybe_put_auth(token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(400)

    assert malformed_response == invalid_json_response()

    missing_content_type_response =
      conn(:post, "/api/goals", Jason.encode!(%{title: "Goal"}))
      |> maybe_put_auth(token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(415)

    assert unsupported_media_type?(missing_content_type_response)
  end

  test "goal task link REST returns not_found for missing and malformed task ids" do
    {token, _list_id} = registered_token_and_list_id()

    assert %{"data" => %{"goal" => %{"id" => goal_id}}} =
             :post
             |> json_conn("/api/goals", %{title: "Goal"}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    for body <- [%{}, %{task_id: nil}, %{task_id: "not-a-uuid"}] do
      assert %{"error" => %{"code" => "not_found"}} =
               :post
               |> json_conn("/api/goals/#{goal_id}/tasks", body, token)
               |> TodexWeb.Router.call(@opts)
               |> json_response(404)
    end
  end

  test "REST timestamp fields parse as ISO8601 timestamps" do
    {token, _list_id} = registered_token_and_list_id()

    assert %{"data" => %{"goal" => goal}} =
             :post
             |> json_conn("/api/goals", %{title: "Timed"}, token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(201)

    assert {:ok, _, 0} = DateTime.from_iso8601(goal["inserted_at"])
    assert {:ok, _, 0} = DateTime.from_iso8601(goal["updated_at"])
  end

  test "protected endpoints reject missing bearer tokens" do
    response =
      conn(:get, "/api/lists")
      |> TodexWeb.Router.call(@opts)
      |> json_response(401)

    assert response == %{
             "error" => %{
               "code" => "unauthorized",
               "message" => "Unauthorized",
               "details" => %{}
             }
           }
  end

  test "register rejects malformed JSON and missing or wrong content type" do
    malformed_response =
      conn(:post, "/api/auth/register", "{")
      |> put_req_header("content-type", "application/json")
      |> TodexWeb.Router.call(@opts)
      |> json_response(400)

    assert malformed_response == invalid_json_response()

    missing_content_type_response =
      conn(:post, "/api/auth/register", Jason.encode!(%{email: "missing@example.com"}))
      |> TodexWeb.Router.call(@opts)
      |> json_response(415)

    assert unsupported_media_type?(missing_content_type_response)

    wrong_content_type_response =
      conn(:post, "/api/auth/register", "email=wrong@example.com")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> TodexWeb.Router.call(@opts)
      |> json_response(415)

    assert unsupported_media_type?(wrong_content_type_response)

    invalid_json_media_type_response =
      conn(:post, "/api/auth/register", Jason.encode!(%{email: "jsonx@example.com"}))
      |> put_req_header("content-type", "application/jsonx")
      |> TodexWeb.Router.call(@opts)
      |> json_response(415)

    assert unsupported_media_type?(invalid_json_media_type_response)
  end

  test "create task rejects malformed JSON and missing or wrong content type" do
    {token, list_id} = registered_token_and_list_id()

    malformed_response =
      conn(:post, "/api/tasks", "{")
      |> put_req_header("content-type", "application/json")
      |> maybe_put_auth(token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(400)

    assert malformed_response == invalid_json_response()

    missing_content_type_response =
      conn(:post, "/api/tasks", Jason.encode!(%{title: "Task", list_id: list_id}))
      |> maybe_put_auth(token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(415)

    assert unsupported_media_type?(missing_content_type_response)

    wrong_content_type_response =
      conn(:post, "/api/tasks", "title=Task")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> maybe_put_auth(token)
      |> TodexWeb.Router.call(@opts)
      |> json_response(415)

    assert unsupported_media_type?(wrong_content_type_response)
  end

  defp json_conn(method, path, body, token \\ nil) do
    method
    |> conn(path, Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> maybe_put_auth(token)
  end

  defp auth_conn(method, path, token) do
    method
    |> conn(path)
    |> maybe_put_auth(token)
  end

  defp maybe_put_auth(conn, nil), do: conn
  defp maybe_put_auth(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token}")

  defp registered_token_and_list_id do
    {_email, token} = registered_user("content-type")
    list_id = first_list_id(token)

    {token, list_id}
  end

  defp registered_token_and_note_folder_id do
    {_email, token} = registered_user("note-rest")
    folder_id = first_note_folder_id(token)

    {token, folder_id}
  end

  defp registered_user(tag) do
    email = "#{tag}-#{System.unique_integer([:positive])}@example.com"

    response =
      :post
      |> json_conn("/api/auth/register", %{email: email, password: "super-secret-password"})
      |> TodexWeb.Router.call(@opts)
      |> json_response(201)

    {email, get_in(response, ["data", "token"])}
  end

  defp first_list_id(token) do
    :get
    |> auth_conn("/api/lists", token)
    |> TodexWeb.Router.call(@opts)
    |> json_response(200)
    |> get_in(["data", "lists"])
    |> hd()
    |> Map.fetch!("id")
  end

  defp first_note_folder_id(token) do
    :get
    |> auth_conn("/api/note-folders", token)
    |> TodexWeb.Router.call(@opts)
    |> json_response(200)
    |> get_in(["data", "note_folders"])
    |> hd()
    |> Map.fetch!("id")
  end

  defp user_id(token) do
    :get
    |> auth_conn("/api/auth/me", token)
    |> TodexWeb.Router.call(@opts)
    |> json_response(200)
    |> get_in(["data", "user", "id"])
  end

  defp forwarding_transport(test_pid, tag) do
    spawn(fn ->
      forward_messages(test_pid, tag)
    end)
  end

  defp forward_messages(test_pid, tag) do
    receive do
      payload ->
        send(test_pid, {tag, payload})
        forward_messages(test_pid, tag)
    end
  end

  defp unsupported_media_type?(response) do
    response == %{
      "error" => %{
        "code" => "unsupported_media_type",
        "message" => "Content-Type must be application/json",
        "details" => %{}
      }
    }
  end

  defp invalid_json_response do
    %{
      "error" => %{
        "code" => "invalid_json",
        "message" => "Invalid JSON request body",
        "details" => %{}
      }
    }
  end

  defp json_response(conn, status) do
    assert conn.status == status
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    Jason.decode!(conn.resp_body)
  end
end
