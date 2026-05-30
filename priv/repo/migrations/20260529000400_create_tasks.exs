defmodule Todex.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      # Composite FK (list_id, user_id) → lists(id, user_id) enforces at the DB level
      # that a task's user_id must match the user_id of the referenced list.
      add :list_id,
          references(:lists,
            type: :binary_id,
            with: [user_id: :user_id],
            on_delete: :delete_all
          ),
          null: false

      add :title, :string, null: false
      add :notes, :text
      add :status, :string, null: false, default: "active"
      add :due_date, :date
      add :completed_at, :utc_datetime
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:user_id])
    create index(:tasks, [:list_id])
    create index(:tasks, [:user_id, :status])
    create index(:tasks, [:user_id, :due_date])

    create constraint(:tasks, :tasks_status_check, check: "status IN ('active', 'completed')")

    # GIN trigram indexes to support efficient ILIKE searches on title and notes
    execute(
      "CREATE INDEX tasks_title_trgm_idx ON tasks USING gin (title gin_trgm_ops)",
      "DROP INDEX IF EXISTS tasks_title_trgm_idx"
    )

    execute(
      "CREATE INDEX tasks_notes_trgm_idx ON tasks USING gin (notes gin_trgm_ops)",
      "DROP INDEX IF EXISTS tasks_notes_trgm_idx"
    )
  end
end
