defmodule Todex.Accounts.AuthToken do
  use Ecto.Schema

  import Ecto.Changeset

  alias Todex.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime, updated_at: false]

  schema "auth_tokens" do
    field(:token_hash, :string)
    field(:expires_at, :utc_datetime)

    belongs_to(:user, User)

    timestamps()
  end

  def changeset(auth_token, attrs) do
    auth_token
    |> cast(attrs, [:user_id, :token_hash, :expires_at])
    |> validate_required([:user_id, :token_hash, :expires_at])
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id)
  end
end
