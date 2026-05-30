defmodule Todex.Onboarding do
  @moduledoc """
  Orchestrates new-user registration: creates the account, seeds the user's
  default todo lists and note folders, and issues an auth token — all inside a
  single transaction.

  This keeps the `Todex.Accounts` core auth context from reaching into the
  feature contexts (`Todex.Todos`, `Todex.Notes`); the cross-context
  orchestration lives here instead.
  """

  alias Ecto.Multi
  alias Todex.Accounts
  alias Todex.Notes
  alias Todex.Repo
  alias Todex.Todos

  @doc """
  Registers a user with seeded defaults and an issued token.

  Returns `{:ok, %{user: ..., token: ..., ...}}` on success or
  `{:error, reason}` on failure, matching the previous
  `Todex.Accounts.register_user/1` contract.
  """
  def register_user(attrs) do
    Multi.new()
    |> Multi.insert(:user, Accounts.registration_changeset(attrs))
    |> Multi.run(:default_lists, fn repo, %{user: user} ->
      Todos.seed_default_lists(repo, user)
    end)
    |> Multi.run(:default_note_folders, fn repo, %{user: user} ->
      Notes.seed_default_folders(repo, user)
    end)
    |> Multi.run(:token, fn repo, %{user: user} -> Accounts.issue_token(repo, user) end)
    |> Repo.transaction()
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end
end
