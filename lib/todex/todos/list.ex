defmodule Todex.Todos.List do
  use Ecto.Schema

  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Todos.Task

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "lists" do
    field(:name, :string)
    field(:icon, :string)
    field(:color, :string)
    field(:position, :integer, default: 0)
    field(:is_default, :boolean, default: false)

    belongs_to(:user, User)
    has_many(:tasks, Task)

    timestamps()
  end

  def changeset(list, attrs) do
    list
    |> cast(attrs, [:user_id, :name, :icon, :color, :position])
    |> validate_required([:user_id, :name])
    |> validate_length(:name, min: 1, max: 80)
    |> unique_constraint(:name, name: :lists_user_id_name_index)
    |> foreign_key_constraint(:user_id)
  end

  def seed_changeset(list, attrs) do
    list
    |> changeset(attrs)
    |> cast(attrs, [:is_default])
  end
end
