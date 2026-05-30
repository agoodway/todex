defmodule Todex.Todos.Task do
  @moduledoc """
  Schema and changeset for a task belonging to a list and a user.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Todos.List

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  @statuses [:active, :completed]

  schema "tasks" do
    field(:title, :string)
    field(:notes, :string)
    field(:status, Ecto.Enum, values: @statuses, default: :active)
    field(:due_date, :date)
    field(:completed_at, :utc_datetime)
    field(:position, :integer, default: 0)

    belongs_to(:user, User)
    belongs_to(:list, List)

    timestamps()
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :user_id,
      :list_id,
      :title,
      :notes,
      :status,
      :due_date,
      :completed_at,
      :position
    ])
    |> validate_required([:user_id, :list_id, :title])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:notes, max: 100_000)
    |> validate_inclusion(:status, @statuses)
    |> check_constraint(:status, name: :tasks_status_check)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:list_id)
  end
end
