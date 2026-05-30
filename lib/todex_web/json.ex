defmodule TodexWeb.Json do
  alias Todex.Accounts.User
  alias Todex.Notes.Note
  alias Todex.Notes.NoteFolder
  alias Todex.Todos.List
  alias Todex.Todos.Task

  def user(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      inserted_at: datetime(user.inserted_at),
      updated_at: datetime(user.updated_at)
    }
  end

  def list(%List{} = list) do
    %{
      id: list.id,
      name: list.name,
      icon: list.icon,
      color: list.color,
      position: list.position,
      is_default: list.is_default,
      inserted_at: datetime(list.inserted_at),
      updated_at: datetime(list.updated_at)
    }
  end

  def task(%Task{} = task) do
    %{
      id: task.id,
      list_id: task.list_id,
      title: task.title,
      notes: task.notes,
      status: status(task.status),
      due_date: date(task.due_date),
      completed_at: datetime(task.completed_at),
      position: task.position,
      inserted_at: datetime(task.inserted_at),
      updated_at: datetime(task.updated_at)
    }
  end

  def note_folder(%NoteFolder{} = folder) do
    %{
      id: folder.id,
      name: folder.name,
      position: folder.position,
      is_default: folder.is_default,
      inserted_at: datetime(folder.inserted_at),
      updated_at: datetime(folder.updated_at)
    }
  end

  def note(%Note{} = note) do
    %{
      id: note.id,
      folder_id: note.folder_id,
      title: note.title,
      body: note.body,
      pinned: note.pinned,
      position: note.position,
      deleted_at: datetime(note.deleted_at),
      inserted_at: datetime(note.inserted_at),
      updated_at: datetime(note.updated_at)
    }
  end

  defp status(nil), do: nil
  defp status(status), do: Atom.to_string(status)

  defp date(nil), do: nil
  defp date(%Date{} = date), do: Date.to_iso8601(date)

  defp datetime(nil), do: nil
  defp datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp datetime(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_iso8601(datetime)
end
