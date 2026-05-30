defmodule Todex.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "users" do
    # The DB column is citext (case-insensitive text). Ecto maps it as :string, which is
    # correct for read/write. Case-insensitive uniqueness is enforced by the DB citext type.
    # normalize_email/1 also downcases on write to keep values consistently lowercase.
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    # The DB column is :text (not varchar) so it is hash-algorithm-agnostic.
    field(:password_hash, :string, redact: true)

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 8, max: 72)
    |> unique_constraint(:email)
    |> hash_password()
  end

  def normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  def normalize_email(email), do: email

  defp hash_password(%Ecto.Changeset{valid?: true} = changeset) do
    password = get_change(changeset, :password)

    if password do
      put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    else
      changeset
    end
  end

  defp hash_password(changeset), do: changeset
end
