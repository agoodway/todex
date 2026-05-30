defmodule Todex.Repo.Migrations.CreateLists do
  use Ecto.Migration

  def change do
    create table(:lists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :icon, :string
      add :color, :string
      add :position, :integer, null: false, default: 0
      # is_default marks system-seeded lists (Personal, Work, Fitness, Groceries).
      # Multiple lists per user CAN have is_default = true, so a single-default
      # partial unique index is intentionally NOT added here.
      add :is_default, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:lists, [:user_id])
    create unique_index(:lists, [:user_id, :name])
    # Composite unique on (id, user_id) is the target for the composite FK from tasks,
    # which enforces that a task's user_id matches its list's user_id at the DB level.
    create unique_index(:lists, [:id, :user_id], name: :lists_id_user_id_index)
  end
end
