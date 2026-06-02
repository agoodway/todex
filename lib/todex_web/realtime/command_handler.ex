defmodule TodexWeb.Realtime.CommandHandler do
  alias Todex.Goals
  alias Todex.Notes
  alias Todex.Sharing
  alias Todex.Todos
  alias TodexWeb.Errors
  alias TodexWeb.Json

  def handle(user, %{"id" => id, "type" => type, "payload" => payload}) when is_map(payload) do
    dispatch(user, id, type, payload)
  end

  def handle(_user, %{"id" => id}) do
    {:error, error_response(id, "invalid_envelope", "Invalid command envelope")}
  end

  def handle(_user, _envelope) do
    {:error, error_response(nil, "invalid_envelope", "Invalid command envelope")}
  end

  defp dispatch(user, id, "list:create", payload) do
    user
    |> Todos.create_list(payload)
    |> result(id, :list, "list:created")
  end

  defp dispatch(user, id, "list:update", payload) do
    user
    |> Todos.update_list(payload_id(payload), payload)
    |> result(id, :list, "list:updated")
  end

  defp dispatch(user, id, "list:delete", payload) do
    list_id = payload_id(payload)

    user
    |> Todos.delete_list(list_id)
    |> result(id, :list, "list:deleted")
  end

  defp dispatch(user, id, "task:create", payload) do
    user
    |> Todos.create_task(payload)
    |> result(id, :task, "task:created")
  end

  defp dispatch(user, id, "task:update", payload) do
    user
    |> Todos.update_task(payload_id(payload), payload)
    |> result(id, :task, "task:updated")
  end

  defp dispatch(user, id, "task:delete", payload) do
    task_id = payload_id(payload)

    user
    |> Todos.delete_task(task_id)
    |> result(id, :task, "task:deleted")
  end

  defp dispatch(user, id, "task:complete", payload) do
    user
    |> Todos.complete_task(payload_id(payload))
    |> result(id, :task, "task:updated")
  end

  defp dispatch(user, id, "task:reopen", payload) do
    user
    |> Todos.reopen_task(payload_id(payload))
    |> result(id, :task, "task:updated")
  end

  defp dispatch(user, id, "goal:create", payload) do
    user
    |> Goals.create_goal(payload)
    |> result(id, :goal, "goal:created")
  end

  defp dispatch(user, id, "goal:update", payload) do
    user
    |> Goals.update_goal(payload_id(payload), payload)
    |> result(id, :goal, "goal:updated")
  end

  defp dispatch(user, id, "goal:delete", payload) do
    user
    |> Goals.delete_goal(payload_id(payload))
    |> result(id, :goal, "goal:deleted")
  end

  defp dispatch(user, id, "goal:link_task", payload) do
    user
    |> Goals.link_task(payload_id(payload), task_id(payload))
    |> result(id, :goal, "goal:updated")
  end

  defp dispatch(user, id, "goal:unlink_task", payload) do
    user
    |> Goals.unlink_task(payload_id(payload), task_id(payload))
    |> result(id, :goal, "goal:updated")
  end

  defp dispatch(user, id, "note_folder:create", payload) do
    user
    |> Notes.create_folder(payload)
    |> result(id, :note_folder, "note_folder:created")
  end

  defp dispatch(user, id, "note_folder:update", payload) do
    user
    |> Notes.update_folder(payload_id(payload), payload)
    |> result(id, :note_folder, "note_folder:updated")
  end

  defp dispatch(user, id, "note_folder:delete", payload) do
    user
    |> Notes.delete_folder(payload_id(payload))
    |> result(id, :note_folder, "note_folder:deleted")
  end

  defp dispatch(user, id, "note:create", payload) do
    user
    |> Notes.create_note(payload)
    |> result(id, :note, "note:created")
  end

  defp dispatch(user, id, "note:update", payload) do
    user
    |> Notes.update_note(payload_id(payload), payload)
    |> result(id, :note, "note:updated")
  end

  defp dispatch(user, id, "note:delete", payload) do
    user
    |> Notes.soft_delete_note(payload_id(payload))
    |> result(id, :note, "note:deleted")
  end

  defp dispatch(user, id, "note:pin", payload) do
    user
    |> Notes.pin_note(payload_id(payload))
    |> result(id, :note, "note:updated")
  end

  defp dispatch(user, id, "note:unpin", payload) do
    user
    |> Notes.unpin_note(payload_id(payload))
    |> result(id, :note, "note:updated")
  end

  defp dispatch(user, id, "note:restore", payload) do
    user
    |> Notes.restore_note(payload_id(payload))
    |> result(id, :note, "note:restored")
  end

  defp dispatch(user, id, "note:permanent_delete", payload) do
    user
    |> Notes.permanently_delete_note(payload_id(payload))
    |> result(id, :note, "note:permanently_deleted")
  end

  defp dispatch(_user, id, _type, _payload) do
    {:error, error_response(id, "unknown_command", "Unknown command")}
  end

  defp result({:ok, record}, id, key, event_type) do
    payload = record_payload(key, record)
    {:ok, ok_response(id, payload), broadcasts(record, key, event_type, payload)}
  end

  defp result({:ok, task, affected_goals}, id, :task, event_type) do
    payload = record_payload(:task, task)
    {:ok, ok_response(id, payload), task_broadcasts(event_type, payload, task, affected_goals)}
  end

  defp result({:error, reason}, id, _key, _event_type) do
    {:error, error_response(id, reason)}
  end

  defp record_payload(:list, list), do: %{list: Json.list(list)}
  defp record_payload(:task, task), do: %{task: Json.task(task)}
  defp record_payload(:goal, goal), do: %{goal: Json.goal(goal)}
  defp record_payload(:note_folder, folder), do: %{note_folder: Json.note_folder(folder)}
  defp record_payload(:note, note), do: %{note: Json.note(note)}

  defp task_broadcasts(event_type, payload, task, affected_goals) do
    # Task writes can affect multiple linked goals. Each goal update remains a
    # separate event to preserve the existing realtime protocol shape.
    goal_broadcasts =
      affected_goals
      |> Enum.map(fn goal ->
        %{type: "goal:updated", payload: record_payload(:goal, goal), recipients: [goal.user_id]}
      end)

    [
      %{type: event_type, payload: payload, recipients: Sharing.list_recipient_ids(task.list_id)}
      | goal_broadcasts
    ]
  end

  defp broadcasts(record, :list, event_type, payload) do
    [%{type: event_type, payload: payload, recipients: Sharing.list_recipient_ids(record.id)}]
  end

  defp broadcasts(record, :note, event_type, payload) do
    [%{type: event_type, payload: payload, recipients: Sharing.note_recipient_ids(record.id)}]
  end

  defp broadcasts(_record, _key, event_type, payload), do: [%{type: event_type, payload: payload}]

  defp payload_id(payload), do: Map.get(payload, "id") || Map.get(payload, :id)

  defp task_id(payload), do: Map.get(payload, "task_id") || Map.get(payload, :task_id)

  defp ok_response(id, payload), do: %{id: id, type: "ok", payload: payload}

  defp error_response(id, code, message, details \\ %{}) do
    %{id: id, type: "error", error: %{code: code, message: message, details: details}}
  end

  defp error_response(id, reason) do
    %{code: code, message: message, details: details} = error_info(reason)
    error_response(id, code, message, details)
  end

  # Reasons enumerated in the shared mapper get identical code/message/details.
  # Unknown reasons fall through to the WS-specific generic catch-all.
  @generic_error %{code: "error", message: "Something went wrong", details: %{}}
  defp error_info(reason), do: Errors.error_info(reason, @generic_error)
end
