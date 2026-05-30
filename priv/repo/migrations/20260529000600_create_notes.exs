defmodule Todex.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create table(:notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      # Composite FK (folder_id, user_id) → note_folders(id, user_id) enforces at the DB
      # level that a note's user_id must match the user_id of the referenced folder.
      add :folder_id,
          references(:note_folders,
            type: :binary_id,
            with: [user_id: :user_id],
            on_delete: :delete_all
          ),
          null: false

      add :title, :string, null: false
      add :body, :text
      add :pinned, :boolean, null: false, default: false
      add :position, :integer, null: false, default: 0
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Standalone index on [:user_id] is omitted: it is fully covered by every composite
    # index below that leads with user_id (user_id, folder_id), (user_id, pinned),
    # (user_id, deleted_at). Keeping it would be a redundant, write-amplifying index.
    create index(:notes, [:folder_id])
    create index(:notes, [:user_id, :folder_id])
    create index(:notes, [:user_id, :pinned])
    create index(:notes, [:user_id, :deleted_at])

    # GIN trigram indexes to support efficient ILIKE searches on title and body
    execute(
      "CREATE INDEX notes_title_trgm_idx ON notes USING gin (title gin_trgm_ops)",
      "DROP INDEX IF EXISTS notes_title_trgm_idx"
    )

    execute(
      "CREATE INDEX notes_body_trgm_idx ON notes USING gin (body gin_trgm_ops)",
      "DROP INDEX IF EXISTS notes_body_trgm_idx"
    )
  end
end
