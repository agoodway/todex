defmodule TodexWeb.Realtime.CommandHandler do
  alias Todex.Notes
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
    {:ok, ok_response(id, payload), %{type: event_type, payload: payload}}
  end

  defp result({:error, reason}, id, _key, _event_type) do
    {:error, error_response(id, reason)}
  end

  defp record_payload(:list, list), do: %{list: Json.list(list)}
  defp record_payload(:task, task), do: %{task: Json.task(task)}
  defp record_payload(:note_folder, folder), do: %{note_folder: Json.note_folder(folder)}
  defp record_payload(:note, note), do: %{note: Json.note(note)}

  defp payload_id(payload), do: Map.get(payload, "id") || Map.get(payload, :id)

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
