defmodule Todex.Notes.Note do
  use Ecto.Schema

  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Notes.NoteFolder

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "notes" do
    field(:title, :string)
    field(:body, :string)
    field(:pinned, :boolean, default: false)
    field(:position, :integer, default: 0)
    field(:deleted_at, :utc_datetime)

    belongs_to(:user, User)
    belongs_to(:folder, NoteFolder)

    timestamps()
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:user_id, :folder_id, :title, :body, :pinned, :position, :deleted_at])
    |> validate_required([:user_id, :folder_id, :title])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:body, max: 100_000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:folder_id)
  end
end
