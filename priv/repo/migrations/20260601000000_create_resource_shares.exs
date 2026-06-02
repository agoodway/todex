defmodule Todex.Repo.Migrations.CreateResourceShares do
  use Ecto.Migration

  def change do
    create table(:list_shares, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :list_id,
          references(:lists,
            type: :binary_id,
            with: [owner_id: :user_id],
            on_delete: :delete_all,
            name: :list_shares_list_owner_fkey
          ),
          null: false

      add :role, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:list_shares, [:owner_id])
    create index(:list_shares, [:recipient_id])
    create index(:list_shares, [:list_id])
    create unique_index(:list_shares, [:list_id, :recipient_id])
    create constraint(:list_shares, :list_shares_role_check, check: "role IN ('viewer', 'editor')")
    create constraint(:list_shares, :list_shares_not_self_check, check: "owner_id <> recipient_id")

    create unique_index(:notes, [:id, :user_id], name: :notes_id_user_id_index)

    create table(:note_shares, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :note_id,
          references(:notes,
            type: :binary_id,
            with: [owner_id: :user_id],
            on_delete: :delete_all,
            name: :note_shares_note_owner_fkey
          ),
          null: false

      add :role, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:note_shares, [:owner_id])
    create index(:note_shares, [:recipient_id])
    create index(:note_shares, [:note_id])
    create unique_index(:note_shares, [:note_id, :recipient_id])
    create constraint(:note_shares, :note_shares_role_check, check: "role IN ('viewer', 'editor')")
    create constraint(:note_shares, :note_shares_not_self_check, check: "owner_id <> recipient_id")
  end
end
