defmodule Todex.Repo.Migrations.CreateNoteFolders do
  use Ecto.Migration

  def change do
    create table(:note_folders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :position, :integer, null: false, default: 0
      add :is_default, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:note_folders, [:user_id])
    create unique_index(:note_folders, [:user_id, :name])
    # Composite unique on (id, user_id) is the target for the composite FK from notes,
    # which enforces that a note's user_id matches its folder's user_id at the DB level.
    create unique_index(:note_folders, [:id, :user_id], name: :note_folders_id_user_id_index)
    # Enforce that each user has at most one default folder
    create unique_index(:note_folders, [:user_id],
             where: "is_default = true",
             name: :note_folders_one_default_per_user
           )
  end
end
