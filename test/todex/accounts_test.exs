defmodule Todex.AccountsTest do
  use Todex.DataCase, async: true

  alias Todex.Accounts
  alias Todex.Onboarding
  alias Todex.Repo
  alias Todex.Todos

  @valid_attrs %{email: "User@Example.com", password: "super-secret-password"}

  test "register_user/1 creates user, token, default lists, and default note folder" do
    assert {:ok, %{user: user, token: token}} = Onboarding.register_user(@valid_attrs)

    assert user.email == "user@example.com"
    assert is_binary(token)

    assert Todos.list_lists(user) |> Enum.map(& &1.name) == [
             "Personal",
             "Work",
             "Fitness",
             "Groceries"
           ]

    assert %{rows: [["Notes", true, 0]]} =
             Repo.query!(
               "select name, is_default, position from note_folders where user_id = $1",
               [Ecto.UUID.dump!(user.id)]
             )
  end

  test "register_user/1 rolls back defaults and token when registration fails" do
    assert {:ok, %{user: user}} = Onboarding.register_user(@valid_attrs)

    assert {:error, changeset} = Onboarding.register_user(@valid_attrs)
    assert %{email: ["has already been taken"]} = errors_on(changeset)

    assert %{rows: [[1]]} =
             Repo.query!("select count(*) from users where email = $1", ["user@example.com"])

    assert %{rows: [[4]]} =
             Repo.query!("select count(*) from lists where user_id = $1", [
               Ecto.UUID.dump!(user.id)
             ])

    assert %{rows: [[1]]} =
             Repo.query!("select count(*) from note_folders where user_id = $1", [
               Ecto.UUID.dump!(user.id)
             ])

    assert %{rows: [[1]]} =
             Repo.query!("select count(*) from auth_tokens where user_id = $1", [
               Ecto.UUID.dump!(user.id)
             ])
  end

  test "login_user/2 returns token for valid credentials and verify_token/1 returns user" do
    assert {:ok, %{user: registered_user}} = Onboarding.register_user(@valid_attrs)

    assert {:ok, %{user: login_user, token: token}} =
             Accounts.login_user(" USER@example.com ", @valid_attrs.password)

    assert login_user.id == registered_user.id
    assert login_user.email == "user@example.com"

    assert {:ok, verified_user} = Accounts.verify_token(token)
    assert verified_user.id == registered_user.id
  end

  test "login_user/2 returns invalid credentials for invalid password" do
    assert {:ok, _result} = Onboarding.register_user(@valid_attrs)

    assert {:error, :invalid_credentials} =
             Accounts.login_user(@valid_attrs.email, "wrong-password")
  end

  test "login_user/2 returns invalid credentials for malformed input" do
    assert {:ok, _result} = Onboarding.register_user(@valid_attrs)

    assert {:error, :invalid_credentials} = Accounts.login_user(nil, @valid_attrs.password)
    assert {:error, :invalid_credentials} = Accounts.login_user(123, @valid_attrs.password)
    assert {:error, :invalid_credentials} = Accounts.login_user(@valid_attrs.email, nil)
    assert {:error, :invalid_credentials} = Accounts.login_user(@valid_attrs.email, 123)
  end

  test "verify_token/1 returns invalid token for malformed tokens" do
    assert {:error, :invalid_token} = Accounts.verify_token("not-a-jwt")
    assert {:error, :invalid_token} = Accounts.verify_token(nil)
  end

  test "register_user/1 returns changeset error for duplicate email" do
    assert {:ok, _result} = Onboarding.register_user(@valid_attrs)

    assert {:error, changeset} = Onboarding.register_user(@valid_attrs)
    assert %{email: ["has already been taken"]} = errors_on(changeset)
  end

  test "logout_token/1 revokes token so verify_token/1 returns invalid token" do
    assert {:ok, %{token: token}} = Onboarding.register_user(@valid_attrs)

    assert :ok = Accounts.logout_token(token)
    assert {:error, :invalid_token} = Accounts.verify_token(token)
  end
end
