defmodule Todex.Repo.Migrations.CreateGoalTasks do
  use Ecto.Migration

  def change do
    create table(:goal_tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :goal_id,
          references(:goals,
            type: :binary_id,
            with: [user_id: :user_id],
            on_delete: :delete_all
          ),
          null: false

      add :task_id,
          references(:tasks,
            type: :binary_id,
            with: [user_id: :user_id],
            on_delete: :delete_all
          ),
          null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:goal_tasks, [:goal_id, :task_id])
    create index(:goal_tasks, [:task_id])
    create index(:goal_tasks, [:user_id])
    create index(:goal_tasks, [:user_id, :task_id])
    create index(:goal_tasks, [:user_id, :goal_id])
  end
end
