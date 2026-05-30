defmodule Todex.Notes do
  import Ecto.Query

  alias Todex.Notes.Note
  alias Todex.Notes.NoteFolder
  alias Todex.Repo

  @default_folder %{name: "Notes", position: 0, is_default: true}

  def seed_default_folders(user), do: seed_default_folders(Repo, user)

  def seed_default_folders(repo, user) do
    %NoteFolder{}
    |> NoteFolder.seed_changeset(Map.put(@default_folder, :user_id, user.id))
    |> repo.insert()
    |> case do
      {:ok, folder} -> {:ok, [folder]}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_folders(user) do
    NoteFolder
    |> where([folder], folder.user_id == ^user.id)
    |> order_by([folder], asc: folder.position, asc: folder.inserted_at)
    |> Repo.all()
  end

  def get_folder(user, id) do
    case cast_uuid(id) do
      {:ok, id} ->
        NoteFolder
        |> where([folder], folder.user_id == ^user.id and folder.id == ^id)
        |> Repo.one()

      :error ->
        nil
    end
  end

  def create_folder(user, attrs) do
    attrs =
      attrs
      |> known_attrs([:name, :position])
      |> Map.put(:user_id, user.id)

    %NoteFolder{}
    |> NoteFolder.changeset(attrs)
    |> Repo.insert()
  end

  def update_folder(user, id, attrs) do
    case get_folder(user, id) do
      nil ->
        {:error, :not_found}

      folder ->
        folder
        |> NoteFolder.changeset(known_attrs(attrs, [:name, :position]))
        |> Repo.update()
    end
  end

  def delete_folder(user, id) do
    with %NoteFolder{} = folder <- get_folder(user, id),
         false <- folder_has_active_notes?(user, folder.id) do
      Repo.transaction(fn ->
        delete_soft_deleted_notes(user, id)
        Repo.delete!(folder)
      end)
    else
      nil -> {:error, :not_found}
      true -> {:error, :folder_has_notes}
    end
  end

  def list_notes(user, params \\ %{}) do
    Note
    |> where([note], note.user_id == ^user.id)
    |> filter_deleted(param(params, :deleted))
    |> filter_folder_id(param(params, :folder_id))
    |> filter_pinned(param(params, :pinned))
    |> filter_search(param(params, :q))
    |> order_by([note], desc: note.pinned, desc: note.updated_at)
    |> Repo.all()
  end

  def get_note(user, id) do
    case cast_uuid(id) do
      {:ok, id} ->
        Note
        |> where([note], note.user_id == ^user.id and note.id == ^id)
        |> Repo.one()

      :error ->
        nil
    end
  end

  def create_note(user, attrs) do
    with {:ok, attrs} <- validate_folder_owner(user, attrs) do
      attrs =
        attrs
        |> known_note_attrs()
        |> Map.put(:user_id, user.id)

      %Note{}
      |> Note.changeset(attrs)
      |> Repo.insert()
    end
  end

  def update_note(user, id, attrs) do
    with %Note{} = note <- get_note(user, id),
         {:ok, attrs} <- validate_folder_owner(user, attrs) do
      note
      |> Note.changeset(known_note_attrs(attrs))
      |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def pin_note(user, id), do: update_note(user, id, %{pinned: true})
  def unpin_note(user, id), do: update_note(user, id, %{pinned: false})

  def soft_delete_note(user, id) do
    set_deleted_at(user, id, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def restore_note(user, id), do: set_deleted_at(user, id, nil)

  defp set_deleted_at(user, id, value) do
    case get_note(user, id) do
      nil ->
        {:error, :not_found}

      note ->
        note
        |> Note.changeset(%{deleted_at: value})
        |> Repo.update()
    end
  end

  def permanently_delete_note(user, id) do
    case get_note(user, id) do
      nil -> {:error, :not_found}
      note -> Repo.delete(note)
    end
  end

  defp folder_has_active_notes?(user, folder_id) do
    Note
    |> where(
      [note],
      note.user_id == ^user.id and note.folder_id == ^folder_id and is_nil(note.deleted_at)
    )
    |> Repo.exists?()
  end

  defp delete_soft_deleted_notes(user, folder_id) do
    Note
    |> where(
      [note],
      note.user_id == ^user.id and note.folder_id == ^folder_id and not is_nil(note.deleted_at)
    )
    |> Repo.delete_all()
  end

  defp validate_folder_owner(user, attrs) do
    case param(attrs, :folder_id) do
      nil ->
        {:ok, attrs}

      folder_id ->
        if get_folder(user, folder_id), do: {:ok, attrs}, else: {:error, :folder_not_found}
    end
  end

  defp filter_deleted(query, value) when value in [true, "true"] do
    where(query, [note], not is_nil(note.deleted_at))
  end

  defp filter_deleted(query, value) when value in [false, "false", nil] do
    where(query, [note], is_nil(note.deleted_at))
  end

  defp filter_deleted(query, _value), do: query

  defp filter_folder_id(query, nil), do: query

  defp filter_folder_id(query, folder_id) do
    case cast_uuid(folder_id) do
      {:ok, folder_id} -> where(query, [note], note.folder_id == ^folder_id)
      :error -> none(query)
    end
  end

  defp filter_pinned(query, value) when value in [true, "true"] do
    where(query, [note], note.pinned == true)
  end

  defp filter_pinned(query, value) when value in [false, "false"] do
    where(query, [note], note.pinned == false)
  end

  defp filter_pinned(query, _value), do: query

  defp filter_search(query, q) when is_binary(q) do
    q = String.trim(q)

    if q == "" do
      query
    else
      escaped =
        q
        |> String.replace("\\", "\\\\")
        |> String.replace("%", "\\%")
        |> String.replace("_", "\\_")

      pattern = "%#{escaped}%"

      where(
        query,
        [note],
        fragment("? ILIKE ? ESCAPE '\\'", note.title, ^pattern) or
          fragment("? ILIKE ? ESCAPE '\\'", note.body, ^pattern)
      )
    end
  end

  defp filter_search(query, _q), do: query

  defp param(attrs, key) when is_map(attrs) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end

  defp param(_attrs, _key), do: nil

  defp cast_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> {:ok, id}
      :error -> :error
    end
  end

  defp none(query), do: where(query, false)

  defp known_note_attrs(attrs) do
    known_attrs(attrs, [:folder_id, :title, :body, :pinned, :position])
  end

  defp known_attrs(attrs, keys) when is_map(attrs) do
    Enum.reduce(keys, %{}, fn key, acc ->
      cond do
        Map.has_key?(attrs, key) ->
          Map.put(acc, key, Map.fetch!(attrs, key))

        Map.has_key?(attrs, Atom.to_string(key)) ->
          Map.put(acc, key, Map.fetch!(attrs, Atom.to_string(key)))

        true ->
          acc
      end
    end)
  end

  defp known_attrs(_attrs, _keys), do: %{}
end
