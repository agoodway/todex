defmodule Todex.Repo.Migrations.CreateAuthTokens do
  use Ecto.Migration

  def change do
    create table(:auth_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false

      # timestamps/1 with updated_at: false emits only inserted_at, matching the schema's
      # @timestamps_opts [type: :utc_datetime, updated_at: false].
      timestamps(updated_at: false, type: :utc_datetime)
    end

    # expires_at index for token-cleanup queries that filter/delete expired tokens
    create index(:auth_tokens, [:expires_at])
    create index(:auth_tokens, [:user_id])
    create unique_index(:auth_tokens, [:token_hash])

    # Ensure tokens cannot have an expiry that precedes their creation time
    create constraint(:auth_tokens, :auth_tokens_expires_after_inserted,
             check: "expires_at > inserted_at"
           )
  end
end
