defmodule TodexWeb.RealtimeCommandHandlerTest do
  use Todex.DataCase, async: true

  alias Todex.Accounts
  alias Todex.Goals
  alias Todex.Notes
  alias Todex.Onboarding
  alias Todex.Realtime
  alias Todex.Todos
  alias TodexWeb.Realtime.CommandHandler

  test "task:create creates a task and returns ok response and created broadcast" do
    %{user: user, list_id: list_id} = registered_user_with_list()

    assert {:ok, response, [broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "1",
               "type" => "task:create",
               "payload" => %{"title" => "Realtime task", "list_id" => list_id}
             })

    assert %{
             id: "1",
             type: "ok",
             payload: %{task: %{id: task_id, title: "Realtime task", status: "active"}}
           } = response

    assert %{
             type: "task:created",
             payload: %{task: %{id: ^task_id, title: "Realtime task", status: "active"}}
           } = broadcast

    assert %{title: "Realtime task"} = Todos.get_task(user, task_id)
  end

  test "unknown command returns error response" do
    %{user: user} = registered_user_with_list()

    assert {:error, response} =
             CommandHandler.handle(user, %{
               "id" => "2",
               "type" => "not:a-command",
               "payload" => %{}
             })

    assert response.id == "2"
    assert response.type == "error"
    assert response.error == %{code: "unknown_command", message: "Unknown command", details: %{}}
  end

  test "list:create creates a list and returns ok response and created broadcast" do
    %{user: user} = registered_user_with_list()

    assert {:ok, response, [broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "3",
               "type" => "list:create",
               "payload" => %{"name" => "Errands", "position" => 20}
             })

    assert %{
             id: "3",
             type: "ok",
             payload: %{list: %{id: list_id, name: "Errands", position: 20}}
           } = response

    assert %{
             type: "list:created",
             payload: %{list: %{id: ^list_id, name: "Errands", position: 20}}
           } = broadcast

    assert Enum.any?(Todos.list_lists(user), &(&1.id == list_id and &1.name == "Errands"))
  end

  test "realtime registry broadcasts JSON events to registered transports" do
    user_id = "user-#{System.unique_integer([:positive])}"

    assert :ok = Realtime.register(user_id, self())
    assert :ok = Realtime.broadcast(user_id, %{type: "ping", payload: %{ok: true}})

    assert_receive payload
    assert Jason.decode!(payload) == %{"payload" => %{"ok" => true}, "type" => "ping"}

    assert :ok = Realtime.unregister(user_id, self())
    assert :ok = Realtime.broadcast(user_id, %{type: "ping", payload: %{ok: false}})
    refute_receive _payload
  end

  test "realtime registry unregisters by transport without a user token" do
    user_id = "user-#{System.unique_integer([:positive])}"
    transport = self()

    assert :ok = Realtime.register(user_id, transport)
    assert :ok = Realtime.unregister_transport(transport)
    assert :ok = Realtime.broadcast(user_id, %{type: "ping", payload: %{ok: true}})

    refute_receive _payload
  end

  test "realtime registry removes transports when monitored transport goes down" do
    user_id = "user-#{System.unique_integer([:positive])}"

    transport =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    assert :ok = Realtime.register(user_id, transport)
    ref = Process.monitor(transport)
    send(transport, :stop)
    assert_receive {:DOWN, ^ref, :process, ^transport, _reason}

    refute Realtime.registered?(user_id, transport)
  end

  test "auth message with revoked token returns unauthorized and unregisters the transport" do
    %{token: token, user: user} = registered_token_user_and_list()
    socket = %{transport: self()}

    # Authenticate first to register, then revoke and re-authenticate with revoked token.
    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)
    :ok = Accounts.logout_token(token)

    auth_msg = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => token}})

    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    assert response == %{
             id: nil,
             type: "error",
             error: %{code: "unauthorized", message: "Unauthorized", details: %{}}
           }

    assert :ok = Realtime.broadcast(user.id, %{type: "ping", payload: %{ok: true}})
    refute_receive _payload
  end

  test "join starts unauthenticated and does not register transport" do
    user_id = "user-#{System.unique_integer([:positive])}"
    socket = %{transport: self()}

    # Pre-register under a user to confirm join does not affect the registry.
    assert :ok = Realtime.register(user_id, self())

    assert :noreply = TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    # Registration made before the join still exists (join has no effect on registry).
    assert Realtime.registered?(user_id, self())

    # Cleanup
    assert :ok = Realtime.unregister(user_id, self())
  end

  test "command message before auth returns unauthorized and does not run commands or affect registrations" do
    user_id = "user-#{System.unique_integer([:positive])}"
    socket = %{transport: self()}

    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)
    assert :ok = Realtime.register(user_id, self())

    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event(
               {:received,
                Jason.encode!(%{
                  "id" => "pre-auth-command",
                  "type" => "list:create",
                  "payload" => %{"name" => "Should not exist"}
                })},
               socket
             )

    assert response == %{
             id: nil,
             type: "error",
             error: %{code: "unauthorized", message: "Unauthorized", details: %{}}
           }

    # The prior Realtime.register is still intact — the command rejection did
    # not unregister it.
    assert Realtime.registered?(user_id, self())

    assert :ok = Realtime.broadcast(user_id, %{type: "ping", payload: %{ok: true}})
    assert_receive _payload

    # Cleanup
    assert :ok = Realtime.unregister(user_id, self())
  end

  test "successful auth handshake then command dispatches correctly" do
    %{token: token, user: user} = registered_token_user_and_list()
    socket = %{transport: self()}

    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    auth_msg = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => token}})

    assert {:reply, %{type: "auth_ok"}} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    assert Realtime.registered?(user.id, self())

    command =
      Jason.encode!(%{
        "id" => "post-auth-cmd",
        "type" => "list:create",
        "payload" => %{"name" => "Post-auth list"}
      })

    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, command}, socket)

    assert response.type == "ok"
    assert response.payload.list.name == "Post-auth list"

    # Cleanup
    assert :ok = Realtime.unregister(user.id, self())
  end

  test "task:delete broadcasts the serialized deleted record" do
    %{user: user, list_id: list_id} = registered_user_with_list()
    assert {:ok, task, []} = Todos.create_task(user, %{title: "Delete me", list_id: list_id})

    assert {:ok, _response, [broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "5",
               "type" => "task:delete",
               "payload" => %{"id" => task.id}
             })

    assert %{
             type: "task:deleted",
             payload: %{task: %{id: task_id, title: "Delete me", status: "active"}}
           } = broadcast

    assert task_id == task.id
  end

  test "task:complete and task:reopen broadcast task:updated" do
    %{user: user, list_id: list_id} = registered_user_with_list()
    assert {:ok, task, []} = Todos.create_task(user, %{title: "Toggle me", list_id: list_id})

    assert {:ok, _response, [complete_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "6",
               "type" => "task:complete",
               "payload" => %{"id" => task.id}
             })

    assert %{type: "task:updated", payload: %{task: %{status: "completed"}}} = complete_broadcast

    assert {:ok, _response, [reopen_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "7",
               "type" => "task:reopen",
               "payload" => %{"id" => task.id}
             })

    assert %{type: "task:updated", payload: %{task: %{status: "active"}}} = reopen_broadcast
  end

  test "goal realtime commands return goal responses and broadcasts" do
    %{user: user, list_id: list_id} = registered_user_with_list()
    assert {:ok, task, []} = Todos.create_task(user, %{title: "Goal task", list_id: list_id})

    assert {:ok, create_response, [create_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "goal-create",
               "type" => "goal:create",
               "payload" => %{"title" => "Launch", "reason" => "Momentum", "progress" => 99}
             })

    assert %{
             id: "goal-create",
             type: "ok",
             payload: %{goal: %{id: goal_id, title: "Launch", reason: "Momentum", progress: 0}}
           } = create_response

    assert %{type: "goal:created", payload: %{goal: %{id: ^goal_id, progress: 0}}} =
             create_broadcast

    assert {:ok, update_response, [update_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "goal-update",
               "type" => "goal:update",
               "payload" => %{"id" => goal_id, "title" => "Updated", "progress" => 50}
             })

    assert %{payload: %{goal: %{id: ^goal_id, title: "Updated", progress: 0}}} =
             update_response

    assert %{type: "goal:updated", payload: %{goal: %{id: ^goal_id, title: "Updated"}}} =
             update_broadcast

    assert {:ok, link_response, [link_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "goal-link",
               "type" => "goal:link_task",
               "payload" => %{"id" => goal_id, "task_id" => task.id}
             })

    assert %{payload: %{goal: %{id: ^goal_id, progress: 0}}} = link_response

    assert %{type: "goal:updated", payload: %{goal: %{id: ^goal_id, progress: 0}}} =
             link_broadcast

    assert {:ok, unlink_response, [unlink_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "goal-unlink",
               "type" => "goal:unlink_task",
               "payload" => %{"id" => goal_id, "task_id" => task.id}
             })

    assert %{payload: %{goal: %{id: ^goal_id, progress: 0}}} = unlink_response

    assert %{type: "goal:updated", payload: %{goal: %{id: ^goal_id, progress: 0}}} =
             unlink_broadcast

    assert {:ok, delete_response, [delete_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "goal-delete",
               "type" => "goal:delete",
               "payload" => %{"id" => goal_id}
             })

    assert %{payload: %{goal: %{id: ^goal_id}}} = delete_response
    assert %{type: "goal:deleted", payload: %{goal: %{id: ^goal_id}}} = delete_broadcast
  end

  test "goal realtime commands return not_found for missing or foreign resources" do
    %{user: user} = registered_user_with_list()
    %{user: other_user, list_id: other_list_id} = registered_user_with_list()
    assert {:ok, other_goal} = Goals.create_goal(other_user, %{title: "Other goal"})

    assert {:ok, other_task, []} =
             Todos.create_task(other_user, %{title: "Other task", list_id: other_list_id})

    for {type, payload} <- [
          {"goal:update", %{"id" => other_goal.id, "title" => "Nope"}},
          {"goal:delete", %{"id" => Ecto.UUID.generate()}},
          {"goal:link_task", %{"id" => other_goal.id, "task_id" => other_task.id}},
          {"goal:unlink_task", %{"id" => Ecto.UUID.generate(), "task_id" => other_task.id}}
        ] do
      assert {:error, response} =
               CommandHandler.handle(user, %{"id" => type, "type" => type, "payload" => payload})

      assert response.error.code == "not_found"
    end
  end

  test "task commands broadcast affected goal updates after task events" do
    %{user: user, list_id: list_id} = registered_user_with_list()
    assert {:ok, task, []} = Todos.create_task(user, %{title: "Fanout task", list_id: list_id})
    assert {:ok, goal_a} = Goals.create_goal(user, %{title: "Goal A"})
    assert {:ok, goal_b} = Goals.create_goal(user, %{title: "Goal B"})
    assert {:ok, _goal_a} = Goals.link_task(user, goal_a.id, task.id)
    assert {:ok, _goal_b} = Goals.link_task(user, goal_b.id, task.id)

    assert {:ok, _response, broadcasts} =
             CommandHandler.handle(user, %{
               "id" => "task-complete-fanout",
               "type" => "task:complete",
               "payload" => %{"id" => task.id}
             })

    assert [task_broadcast, goal_broadcast_a, goal_broadcast_b] = broadcasts

    assert %{type: "task:updated", payload: %{task: %{id: task_id, status: "completed"}}} =
             task_broadcast

    assert task_id == task.id

    assert Enum.map([goal_broadcast_a, goal_broadcast_b], & &1.type) == [
             "goal:updated",
             "goal:updated"
           ]

    assert Enum.sort([goal_a.id, goal_b.id]) ==
             [goal_broadcast_a, goal_broadcast_b]
             |> Enum.map(& &1.payload.goal.id)
             |> Enum.sort()

    assert Enum.all?([goal_broadcast_a, goal_broadcast_b], &(&1.payload.goal.progress == 100))
  end

  test "websocket handler broadcasts every event returned by a command" do
    %{token: token, user: user, list_id: list_id} = registered_token_user_and_list()
    assert {:ok, task, []} = Todos.create_task(user, %{title: "Socket task", list_id: list_id})
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Socket goal"})
    assert {:ok, _goal} = Goals.link_task(user, goal.id, task.id)
    socket = %{transport: self()}

    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    auth_msg = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => token}})

    assert {:reply, %{type: "auth_ok"}} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    command =
      Jason.encode!(%{
        "id" => "socket-task-complete",
        "type" => "task:complete",
        "payload" => %{"id" => task.id}
      })

    assert {:reply, %{type: "ok"}} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, command}, socket)

    assert_receive task_payload
    assert_receive goal_payload

    assert %{"type" => "task:updated", "payload" => %{"task" => %{"id" => task_id}}} =
             Jason.decode!(task_payload)

    assert %{"type" => "goal:updated", "payload" => %{"goal" => %{"id" => goal_id}}} =
             Jason.decode!(goal_payload)

    assert task_id == task.id
    assert goal_id == goal.id

    assert :ok = Realtime.unregister(user.id, self())
  end

  test "websocket command after token revocation returns unauthorized and unregisters transport" do
    %{token: token, user: user} = registered_token_user_and_list()
    socket = %{transport: self()}

    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    auth_msg = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => token}})

    assert {:reply, %{type: "auth_ok"}} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    assert Realtime.registered?(user.id, self())
    :ok = Accounts.logout_token(token)

    command =
      Jason.encode!(%{
        "id" => "revoked-command",
        "type" => "list:create",
        "payload" => %{"name" => "Should not run"}
      })

    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, command}, socket)

    assert response == %{
             id: "revoked-command",
             type: "error",
             error: %{code: "unauthorized", message: "Unauthorized", details: %{}}
           }

    refute Realtime.registered?(user.id, self())
  end

  test "changeset errors return validation_failed with details" do
    %{user: user, list_id: list_id} = registered_user_with_list()

    assert {:error, response} =
             CommandHandler.handle(user, %{
               "id" => "8",
               "type" => "task:create",
               "payload" => %{"title" => "", "list_id" => list_id}
             })

    assert response == %{
             id: "8",
             type: "error",
             error: %{
               code: "validation_failed",
               message: "Validation failed",
               details: %{title: ["can't be blank"]}
             }
           }
  end

  test "goal task realtime commands return not_found for missing and malformed task ids" do
    %{user: user} = registered_user_with_list()
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Goal"})

    for {type, payload} <- [
          {"goal:link_task", %{"id" => goal.id}},
          {"goal:link_task", %{"id" => goal.id, "task_id" => "not-a-uuid"}},
          {"goal:unlink_task", %{"id" => goal.id}},
          {"goal:unlink_task", %{"id" => goal.id, "task_id" => "not-a-uuid"}}
        ] do
      assert {:error, response} =
               CommandHandler.handle(user, %{"id" => type, "type" => type, "payload" => payload})

      assert response.error.code == "not_found"
    end
  end

  test "goal:update ignores client-supplied progress when derived progress is non-zero" do
    %{user: user, list_id: list_id} = registered_user_with_list()

    assert {:ok, task, []} =
             Todos.create_task(user, %{title: "Done", list_id: list_id, status: "completed"})

    assert {:ok, goal} = Goals.create_goal(user, %{title: "Goal"})
    assert {:ok, goal} = Goals.link_task(user, goal.id, task.id)
    assert goal.progress == 100

    assert {:ok, response, [broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "goal-ignore-progress",
               "type" => "goal:update",
               "payload" => %{"id" => goal.id, "progress" => 1, "title" => "Renamed"}
             })

    assert response.payload.goal.progress == 100
    assert broadcast.payload.goal.progress == 100
  end

  test "note realtime commands return ok responses and broadcasts" do
    %{user: user, folder_id: folder_id} = registered_user_with_note_folder()

    assert {:ok, create_response, [create_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "note-1",
               "type" => "note:create",
               "payload" => %{
                 "folder_id" => folder_id,
                 "title" => "Realtime note",
                 "body" => "Body"
               }
             })

    assert %{
             id: "note-1",
             type: "ok",
             payload: %{note: %{id: note_id, title: "Realtime note"}}
           } = create_response

    assert %{type: "note:created", payload: %{note: %{id: ^note_id}}} = create_broadcast

    assert {:ok, _response, [pin_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "note-2",
               "type" => "note:pin",
               "payload" => %{"id" => note_id}
             })

    assert %{type: "note:updated", payload: %{note: %{pinned: true}}} = pin_broadcast

    assert {:ok, _response, [delete_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "note-3",
               "type" => "note:delete",
               "payload" => %{"id" => note_id}
             })

    assert %{type: "note:deleted", payload: %{note: %{deleted_at: deleted_at}}} = delete_broadcast
    assert is_binary(deleted_at)
  end

  test "note folder realtime commands return ok responses and broadcasts" do
    %{user: user} = registered_user_with_note_folder()

    assert {:ok, create_response, [create_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "folder-1",
               "type" => "note_folder:create",
               "payload" => %{"name" => "Realtime folder", "position" => 7}
             })

    assert %{
             id: "folder-1",
             type: "ok",
             payload: %{note_folder: %{id: folder_id, name: "Realtime folder", position: 7}}
           } = create_response

    assert %{type: "note_folder:created", payload: %{note_folder: %{id: ^folder_id}}} =
             create_broadcast

    assert {:ok, _update_response, [update_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "folder-2",
               "type" => "note_folder:update",
               "payload" => %{"id" => folder_id, "name" => "Updated folder"}
             })

    assert %{type: "note_folder:updated", payload: %{note_folder: %{name: "Updated folder"}}} =
             update_broadcast

    assert {:ok, _delete_response, [delete_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "folder-3",
               "type" => "note_folder:delete",
               "payload" => %{"id" => folder_id}
             })

    assert %{type: "note_folder:deleted", payload: %{note_folder: %{id: ^folder_id}}} =
             delete_broadcast
  end

  test "note realtime update, unpin, restore, and permanent delete commands return broadcasts" do
    %{user: user, folder_id: folder_id} = registered_user_with_note_folder()

    assert {:ok, note} =
             Notes.create_note(user, %{folder_id: folder_id, title: "Realtime note", pinned: true})

    assert {:ok, _note} = Notes.soft_delete_note(user, note.id)

    assert {:ok, _update_response, [update_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "note-update",
               "type" => "note:update",
               "payload" => %{"id" => note.id, "title" => "Updated realtime note"}
             })

    assert %{type: "note:updated", payload: %{note: %{title: "Updated realtime note"}}} =
             update_broadcast

    assert {:ok, _unpin_response, [unpin_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "note-unpin",
               "type" => "note:unpin",
               "payload" => %{"id" => note.id}
             })

    assert %{type: "note:updated", payload: %{note: %{pinned: false}}} = unpin_broadcast

    assert {:ok, _restore_response, [restore_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "note-restore",
               "type" => "note:restore",
               "payload" => %{"id" => note.id}
             })

    assert %{type: "note:restored", payload: %{note: %{deleted_at: nil}}} = restore_broadcast

    assert {:ok, _delete_response, [delete_broadcast]} =
             CommandHandler.handle(user, %{
               "id" => "note-permanent-delete",
               "type" => "note:permanent_delete",
               "payload" => %{"id" => note.id}
             })

    assert %{type: "note:permanently_deleted", payload: %{note: %{id: note_id}}} =
             delete_broadcast

    assert note_id == note.id
  end

  test "note realtime commands map folder errors" do
    %{user: user, folder_id: folder_id} = registered_user_with_note_folder()
    assert {:ok, note} = Notes.create_note(user, %{folder_id: folder_id, title: "Blocks delete"})

    assert {:error, response} =
             CommandHandler.handle(user, %{
               "id" => "folder-error",
               "type" => "note_folder:delete",
               "payload" => %{"id" => folder_id}
             })

    assert response.error.code == "folder_has_notes"

    assert {:ok, _note} = Notes.soft_delete_note(user, note.id)

    assert {:error, response} =
             CommandHandler.handle(user, %{
               "id" => "note-error",
               "type" => "note:create",
               "payload" => %{"folder_id" => Ecto.UUID.generate(), "title" => "Missing folder"}
             })

    assert response.error.code == "folder_not_found"
  end

  test "failed auth attempts are capped per connection; past the cap a valid token is rejected without verifying" do
    # The token is VALID and never revoked. If verify_token were still called
    # past the cap, this auth would succeed. Asserting it is rejected proves the
    # cap short-circuits before any verify work happens.
    %{token: token, user: user} = registered_token_user_and_list()
    socket = %{transport: self()}

    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    bad_auth = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => "garbage.not.a.jwt"}})

    # @max_auth_failures is 5; exhaust the failed-auth budget with bad tokens.
    for _ <- 1..5 do
      assert {:reply, response} =
               TodexWeb.WebSocketHandler.handle_ws_event({:received, bad_auth}, socket)

      assert response.error.code == "unauthorized"
    end

    # Past the cap: a VALID token must be rejected without verifying/registering.
    good_auth = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => token}})

    assert {:reply, capped_response} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, good_auth}, socket)

    assert capped_response.error.code == "unauthorized"

    # verify_token was skipped, so the transport was never registered.
    refute Realtime.registered?(user.id, self())
  end

  test "a valid auth before the failure cap succeeds and resets the counter" do
    %{token: token, user: user} = registered_token_user_and_list()
    socket = %{transport: self()}

    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    bad_auth = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => "garbage.not.a.jwt"}})

    # A few failures, but fewer than @max_auth_failures (5).
    for _ <- 1..4 do
      assert {:reply, response} =
               TodexWeb.WebSocketHandler.handle_ws_event({:received, bad_auth}, socket)

      assert response.error.code == "unauthorized"
    end

    # A valid auth before the cap still succeeds.
    auth_msg = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => token}})

    assert {:reply, %{type: "auth_ok"}} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    assert Realtime.registered?(user.id, self())

    # Cleanup
    assert :ok = Realtime.unregister(user.id, self())
  end

  test "re-auth on an already-authenticated connection revalidates token revocation" do
    %{token: token, user: user} = registered_token_user_and_list()
    socket = %{transport: self()}

    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    auth_msg = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => token}})

    assert {:reply, %{type: "auth_ok"}} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    :ok = Accounts.logout_token(token)

    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    assert response.error.code == "unauthorized"
    refute Realtime.registered?(user.id, self())
  end

  defp registered_user_with_list do
    email = "realtime-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    %{user: user, list_id: user |> Todos.list_lists() |> hd() |> Map.fetch!(:id)}
  end

  defp registered_token_user_and_list do
    email = "realtime-token-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user, token: token}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    %{token: token, user: user, list_id: user |> Todos.list_lists() |> hd() |> Map.fetch!(:id)}
  end

  defp registered_user_with_note_folder do
    email = "realtime-notes-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    %{user: user, folder_id: user |> Notes.list_folders() |> hd() |> Map.fetch!(:id)}
  end
end
