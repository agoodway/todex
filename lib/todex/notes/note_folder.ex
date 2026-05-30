defmodule Todex.Notes.NoteFolder do
  use Ecto.Schema

  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Notes.Note

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "note_folders" do
    field(:name, :string)
    field(:position, :integer, default: 0)
    field(:is_default, :boolean, default: false)

    belongs_to(:user, User)
    has_many(:notes, Note, foreign_key: :folder_id)

    timestamps()
  end

  def changeset(folder, attrs) do
    folder
    |> cast(attrs, [:user_id, :name, :position])
    |> validate_required([:user_id, :name])
    |> validate_length(:name, min: 1, max: 80)
    |> unique_constraint(:name, name: :note_folders_user_id_name_index)
    |> foreign_key_constraint(:user_id)
  end

  def seed_changeset(folder, attrs) do
    folder
    |> changeset(attrs)
    |> cast(attrs, [:is_default])
  end
end
