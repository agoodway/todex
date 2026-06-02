defmodule Todex.Sharing do
  import Ecto.Changeset
  import Ecto.Query

  alias Todex.Accounts.User
  alias Todex.Notes.Note
  alias Todex.Repo
  alias Todex.Sharing.ListShare
  alias Todex.Sharing.NoteShare
  alias Todex.Todos.List

  @share_request_types %{recipient_email: :string, role: :string}
  @role_update_types %{role: :string}

  def find_recipient_by_email(email) do
    case normalize_email(email) do
      email when is_binary(email) and email != "" -> Repo.get_by(User, email: email)
      _email -> nil
    end
  end

  def create_list_share(owner, list_id, attrs) do
    with %List{} = list <- get_owned_list(owner, list_id),
         {:ok, attrs} <- validate_share_request(attrs, ListShare.roles()),
         {:ok, recipient} <- resolve_recipient(attrs.recipient_email),
         :ok <- reject_self_share(owner, recipient) do
      if is_nil(recipient) do
        {:ok, nil}
      else
        %ListShare{}
        |> ListShare.changeset(%{
          owner_id: owner.id,
          recipient_id: recipient.id,
          list_id: list.id,
          role: attrs.role
        })
        |> Repo.insert()
        |> normalize_share_insert_error()
      end
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_note_share(owner, note_id, attrs) do
    with %Note{} = note <- get_owned_note(owner, note_id),
         {:ok, attrs} <- validate_share_request(attrs, NoteShare.roles()),
         {:ok, recipient} <- resolve_recipient(attrs.recipient_email),
         :ok <- reject_self_share(owner, recipient) do
      if is_nil(recipient) do
        {:ok, nil}
      else
        %NoteShare{}
        |> NoteShare.changeset(%{
          owner_id: owner.id,
          recipient_id: recipient.id,
          note_id: note.id,
          role: attrs.role
        })
        |> Repo.insert()
        |> normalize_share_insert_error()
      end
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_list_shares(owner, list_id) do
    with %List{} = list <- get_owned_list(owner, list_id) do
      shares =
        ListShare
        |> where([share], share.list_id == ^list.id and share.owner_id == ^owner.id)
        |> order_by([share], asc: share.inserted_at)
        |> preload([:owner, :recipient])
        |> Repo.all()

      {:ok, shares}
    else
      nil -> {:error, :not_found}
    end
  end

  def list_note_shares(owner, note_id) do
    with %Note{} = note <- get_owned_note(owner, note_id) do
      shares =
        NoteShare
        |> where([share], share.note_id == ^note.id and share.owner_id == ^owner.id)
        |> order_by([share], asc: share.inserted_at)
        |> preload([:owner, :recipient])
        |> Repo.all()

      {:ok, shares}
    else
      nil -> {:error, :not_found}
    end
  end

  def update_list_share(owner, list_id, share_id, attrs) do
    with %List{} = list <- get_owned_list(owner, list_id),
         %ListShare{} = share <- get_list_share(owner, list.id, share_id),
         {:ok, attrs} <- validate_role_update(attrs, ListShare.roles()) do
      share
      |> ListShare.changeset(%{role: attrs.role})
      |> Repo.update()
      |> preload_share_result()
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_note_share(owner, note_id, share_id, attrs) do
    with %Note{} = note <- get_owned_note(owner, note_id),
         %NoteShare{} = share <- get_note_share(owner, note.id, share_id),
         {:ok, attrs} <- validate_role_update(attrs, NoteShare.roles()) do
      share
      |> NoteShare.changeset(%{role: attrs.role})
      |> Repo.update()
      |> preload_share_result()
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_list_share(owner, list_id, share_id) do
    with %List{} = list <- get_owned_list(owner, list_id),
         %ListShare{} = share <- get_list_share(owner, list.id, share_id) do
      share
      |> Repo.delete()
      |> preload_share_result()
    else
      nil -> {:error, :not_found}
    end
  end

  def delete_note_share(owner, note_id, share_id) do
    with %Note{} = note <- get_owned_note(owner, note_id),
         %NoteShare{} = share <- get_note_share(owner, note.id, share_id) do
      share
      |> Repo.delete()
      |> preload_share_result()
    else
      nil -> {:error, :not_found}
    end
  end

  def list_shared_lists(recipient, opts \\ []) do
    base =
      ListShare
      |> where([share], share.recipient_id == ^recipient.id)
      |> join(:inner, [share], list in assoc(share, :list))

    total = Repo.aggregate(base, :count, :id)

    items =
      base
      |> order_by([share, list], asc: share.inserted_at)
      |> apply_pagination(opts)
      |> preload([share, list], list: list, owner: [])
      |> Repo.all()
      |> Enum.map(&%{share: &1, list: &1.list})

    {:ok, %{items: items, total: total}}
  end

  def list_shared_notes(recipient, opts \\ []) do
    base =
      NoteShare
      |> where([share], share.recipient_id == ^recipient.id)
      |> join(:inner, [share], note in assoc(share, :note))
      |> where([_share, note], is_nil(note.deleted_at))

    total = Repo.aggregate(base, :count, :id)

    items =
      base
      |> order_by([share, note], asc: share.inserted_at)
      |> apply_pagination(opts)
      |> preload([share, note], note: note, owner: [])
      |> Repo.all()
      |> Enum.map(&%{share: &1, note: &1.note})

    {:ok, %{items: items, total: total}}
  end

  def list_permission(user, list_id) do
    cond do
      get_owned_list(user, list_id) -> :owner
      share = get_list_share_for_recipient(user, list_id) -> share.role
      true -> nil
    end
  end

  def note_permission(user, note_id) do
    cond do
      get_owned_note(user, note_id) -> :owner
      share = get_note_share_for_recipient(user, note_id) -> share.role
      true -> nil
    end
  end

  def can_view_list?(user, list_id),
    do: list_permission(user, list_id) in [:owner, :viewer, :editor]

  def can_edit_list?(user, list_id), do: list_permission(user, list_id) in [:owner, :editor]

  def can_view_note?(user, note_id),
    do: note_permission(user, note_id) in [:owner, :viewer, :editor]

  def can_edit_note?(user, note_id), do: note_permission(user, note_id) in [:owner, :editor]

  def list_recipient_ids(list_id) do
    case Ecto.UUID.cast(list_id) do
      {:ok, list_id} ->
        List
        |> where([list], list.id == ^list_id)
        |> join(:left, [list], share in ListShare, on: share.list_id == list.id)
        |> select([list, share], {list.user_id, share.recipient_id})
        |> Repo.all()
        |> collect_recipient_ids()

      :error ->
        []
    end
  end

  def note_recipient_ids(note_id) do
    case Ecto.UUID.cast(note_id) do
      {:ok, note_id} ->
        Note
        |> where([note], note.id == ^note_id)
        |> join(:left, [note], share in NoteShare, on: share.note_id == note.id)
        |> select([note, share], {note.user_id, share.recipient_id})
        |> Repo.all()
        |> collect_recipient_ids()

      :error ->
        []
    end
  end

  defp get_owned_list(owner, list_id) do
    with {:ok, list_id} <- Ecto.UUID.cast(list_id) do
      Repo.get_by(List, id: list_id, user_id: owner.id)
    else
      :error -> nil
    end
  end

  defp get_owned_note(owner, note_id) do
    with {:ok, note_id} <- Ecto.UUID.cast(note_id) do
      Repo.get_by(Note, id: note_id, user_id: owner.id)
    else
      :error -> nil
    end
  end

  defp get_list_share(owner, list_id, share_id) do
    with {:ok, share_id} <- Ecto.UUID.cast(share_id) do
      Repo.get_by(ListShare, id: share_id, owner_id: owner.id, list_id: list_id)
    else
      :error -> nil
    end
  end

  defp get_note_share(owner, note_id, share_id) do
    with {:ok, share_id} <- Ecto.UUID.cast(share_id) do
      Repo.get_by(NoteShare, id: share_id, owner_id: owner.id, note_id: note_id)
    else
      :error -> nil
    end
  end

  defp get_list_share_for_recipient(recipient, list_id) do
    with {:ok, list_id} <- Ecto.UUID.cast(list_id) do
      Repo.get_by(ListShare, recipient_id: recipient.id, list_id: list_id)
    else
      :error -> nil
    end
  end

  defp get_note_share_for_recipient(recipient, note_id) do
    with {:ok, note_id} <- Ecto.UUID.cast(note_id) do
      Repo.get_by(NoteShare, recipient_id: recipient.id, note_id: note_id)
    else
      :error -> nil
    end
  end

  defp validate_share_request(attrs, roles) do
    {%{}, @share_request_types}
    |> cast(attrs, [:recipient_email, :role])
    |> update_change(:recipient_email, &normalize_email/1)
    |> validate_required([:recipient_email, :role])
    |> validate_format(:recipient_email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_inclusion(:role, Enum.map(roles, &Atom.to_string/1))
    |> apply_action(:insert)
  end

  defp validate_role_update(attrs, roles) do
    {%{}, @role_update_types}
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, Enum.map(roles, &Atom.to_string/1))
    |> apply_action(:update)
  end

  defp apply_pagination(query, opts) do
    case {Keyword.get(opts, :page), Keyword.get(opts, :page_size)} do
      {page, page_size}
      when is_integer(page) and is_integer(page_size) and page > 0 and page_size > 0 ->
        query
        |> limit(^page_size)
        |> offset(^((page - 1) * page_size))

      _no_pagination ->
        query
    end
  end

  defp collect_recipient_ids(rows) do
    rows
    |> Enum.flat_map(fn {owner_id, recipient_id} -> [owner_id, recipient_id] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp resolve_recipient(email), do: {:ok, find_recipient_by_email(email)}

  defp reject_self_share(owner, %{id: owner_id}) when owner_id == owner.id,
    do: {:error, :cannot_share_with_self}

  defp reject_self_share(_owner, _recipient), do: :ok

  defp normalize_share_insert_error({:error, changeset}) do
    if duplicate_share_error?(changeset),
      do: {:error, :share_already_exists},
      else: {:error, changeset}
  end

  defp normalize_share_insert_error(result), do: result

  defp preload_share_result({:ok, share}), do: {:ok, Repo.preload(share, [:owner, :recipient])}
  defp preload_share_result(result), do: result

  defp duplicate_share_error?(changeset) do
    Enum.any?(changeset.errors, fn
      {:recipient_id, {_message, opts}} -> opts[:constraint] == :unique
      _error -> false
    end)
  end

  defp normalize_email(email) when is_binary(email), do: User.normalize_email(email)
  defp normalize_email(email), do: email
end
