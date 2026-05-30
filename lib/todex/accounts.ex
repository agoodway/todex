defmodule Todex.Accounts do
  import Ecto.Query

  require Logger

  alias Todex.Accounts.AuthToken
  alias Todex.Accounts.User
  alias Todex.Repo

  @doc """
  Builds the registration changeset for a new user.

  Exposed for orchestration (e.g. `Todex.Onboarding`) so that the account
  domain remains the owner of user-registration validation.
  """
  def registration_changeset(attrs) do
    User.registration_changeset(%User{}, attrs)
  end

  @doc """
  Issues and persists an auth token for `user` using the given `repo`.

  Usable inside an `Ecto.Multi.run/3` step. Token logic stays in the account
  domain; this is the public entry point for orchestration modules.
  """
  def issue_token(repo, user) do
    with {:ok, token, claims} <-
           Joken.generate_and_sign(token_config(), %{"sub" => user.id}, signer()),
         {:ok, _auth_token} <- persist_token(repo, user, claims) do
      {:ok, token}
    end
  end

  def login_user(email, password) when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: normalize_email(email))

    cond do
      is_nil(user) ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      Bcrypt.verify_pass(password, user.password_hash) ->
        case issue_token(Repo, user) do
          {:ok, token} -> {:ok, %{user: user, token: token}}
          error -> error
        end

      true ->
        {:error, :invalid_credentials}
    end
  end

  def login_user(_email, _password) do
    Bcrypt.no_user_verify()
    {:error, :invalid_credentials}
  end

  def verify_token(token) when is_binary(token) do
    with {:ok, %{"jti" => jti}} <- Joken.verify_and_validate(token_config(), token, signer()),
         %AuthToken{} = auth_token <- get_auth_token(jti) do
      {:ok, auth_token.user}
    else
      _ -> {:error, :invalid_token}
    end
  end

  def verify_token(_token), do: {:error, :invalid_token}

  def logout_token(token) when is_binary(token) do
    case Joken.verify_and_validate(token_config(), token, signer()) do
      {:ok, %{"jti" => jti}} ->
        case Repo.get_by(AuthToken, token_hash: token_hash(jti)) do
          nil ->
            Logger.warning("logout_token: token not found in DB (already revoked or expired)")

          %AuthToken{} = auth_token ->
            case Repo.delete(auth_token) do
              {:ok, _} ->
                :ok

              {:error, reason} ->
                Logger.warning("logout_token: delete failed: #{inspect(reason)}")
            end
        end

      _ ->
        Logger.warning("logout_token: could not validate JWT during logout")
    end

    :ok
  end

  def logout_token(_token), do: :ok

  defp persist_token(repo, user, %{"exp" => expires_at, "jti" => jti}) do
    %AuthToken{}
    |> AuthToken.changeset(%{
      user_id: user.id,
      token_hash: token_hash(jti),
      expires_at: expires_at |> DateTime.from_unix!() |> DateTime.truncate(:second)
    })
    |> repo.insert()
  end

  defp get_auth_token(jti) do
    now = DateTime.utc_now()

    AuthToken
    |> where(
      [auth_token],
      auth_token.token_hash == ^token_hash(jti) and auth_token.expires_at > ^now
    )
    |> preload(:user)
    |> Repo.one()
  end

  defp token_config do
    jwt_config = jwt_config()

    Joken.Config.default_claims(
      iss: Keyword.fetch!(jwt_config, :issuer),
      aud: Keyword.fetch!(jwt_config, :audience),
      default_exp: Keyword.fetch!(jwt_config, :ttl_seconds)
    )
  end

  defp signer do
    Joken.Signer.create("HS256", Keyword.fetch!(jwt_config(), :secret))
  end

  defp jwt_config, do: Application.fetch_env!(:todex, :jwt)

  defp token_hash(jti) do
    :crypto.hash(:sha256, jti)
    |> Base.encode16(case: :lower)
  end

  defp normalize_email(email), do: User.normalize_email(email)
end
