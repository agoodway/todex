defmodule Todex.Sharing.NoteShare do
  use Ecto.Schema

  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Notes.Note

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  @roles [:viewer, :editor]

  schema "note_shares" do
    field(:role, Ecto.Enum, values: @roles)

    belongs_to(:owner, User)
    belongs_to(:recipient, User)
    belongs_to(:note, Note)

    timestamps()
  end

  def changeset(share, attrs) do
    share
    |> cast(attrs, [:owner_id, :recipient_id, :note_id, :role])
    |> validate_required([:owner_id, :recipient_id, :note_id, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_not_self_share()
    |> check_constraint(:role, name: :note_shares_role_check)
    |> foreign_key_constraint(:owner_id)
    |> foreign_key_constraint(:recipient_id)
    |> foreign_key_constraint(:note_id, name: :note_shares_note_owner_fkey)
    |> unique_constraint(:recipient_id, name: :note_shares_note_id_recipient_id_index)
  end

  def roles, do: @roles

  defp validate_not_self_share(changeset) do
    owner_id = get_field(changeset, :owner_id)
    recipient_id = get_field(changeset, :recipient_id)

    if owner_id && owner_id == recipient_id do
      add_error(changeset, :recipient_id, "cannot share with self")
    else
      changeset
    end
  end
end
