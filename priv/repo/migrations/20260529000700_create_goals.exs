defmodule Todex.Repo.Migrations.CreateGoals do
  use Ecto.Migration

  def change do
    create table(:goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :reason, :text
      add :progress, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:goals, [:user_id, :inserted_at])
    create unique_index(:goals, [:id, :user_id])
    create unique_index(:tasks, [:id, :user_id])

    create constraint(:goals, :goals_progress_check, check: "progress >= 0 AND progress <= 100")
  end
end
