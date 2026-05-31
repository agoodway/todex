defmodule Todex.Goals.Goal do
  use Ecto.Schema

  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Goals.GoalTask
  alias Todex.Todos.Task

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "goals" do
    field(:title, :string)
    field(:description, :string)
    field(:reason, :string)
    field(:progress, :integer, default: 0)

    belongs_to(:user, User)
    has_many(:goal_tasks, GoalTask)
    many_to_many(:tasks, Task, join_through: GoalTask)

    timestamps()
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:user_id, :title, :description, :reason])
    |> validate_required([:user_id, :title])
    |> validate_length(:title, min: 1, max: 255)
    |> check_constraint(:progress, name: :goals_progress_check)
    |> foreign_key_constraint(:user_id)
  end
end
