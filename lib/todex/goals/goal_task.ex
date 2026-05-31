defmodule Todex.Goals.GoalTask do
  use Ecto.Schema

  import Ecto.Changeset

  alias Todex.Accounts.User
  alias Todex.Goals.Goal
  alias Todex.Todos.Task

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "goal_tasks" do
    belongs_to(:user, User)
    belongs_to(:goal, Goal)
    belongs_to(:task, Task)

    timestamps()
  end

  def changeset(goal_task, attrs) do
    goal_task
    |> cast(attrs, [:user_id, :goal_id, :task_id])
    |> validate_required([:user_id, :goal_id, :task_id])
    |> unique_constraint([:goal_id, :task_id], name: :goal_tasks_goal_id_task_id_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:task_id)
  end
end
