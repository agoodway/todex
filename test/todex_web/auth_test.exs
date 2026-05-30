defmodule TodexWeb.AuthTest do
  @moduledoc """
  Authentication tests: revoked tokens, tampered/garbage tokens, and
  the no_user_verify path for nonexistent email.
  """

  use Todex.DataCase, async: true

  import Plug.Conn
  import Plug.Test

  alias Todex.Accounts
  alias Todex.Onboarding

  @opts TodexWeb.Router.init([])

  defp json_conn(method, path, body, token \\ nil) do
    conn =
      method
      |> conn(path, Jason.encode!(body))
      |> put_req_header("content-type", "application/json")

    if token, do: put_req_header(conn, "authorization", "Bearer #{token}"), else: conn
  end

  defp auth_conn(method, path, token) do
    method
    |> conn(path)
    |> put_req_header("authorization", "Bearer #{token}")
  end

  defp json_response(conn, status) do
    assert conn.status == status
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    Jason.decode!(conn.resp_body)
  end

  @unauthorized_response %{
    "error" => %{
      "code" => "unauthorized",
      "message" => "Unauthorized",
      "details" => %{}
    }
  }

  # ---------------------------------------------------------------------------
  # Revoked token
  # ---------------------------------------------------------------------------

  test "revoked token returns 401 on a protected endpoint" do
    email = "auth-revoke-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{token: token}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    :ok = Accounts.logout_token(token)

    assert @unauthorized_response ==
             :get
             |> auth_conn("/api/lists", token)
             |> TodexWeb.Router.call(@opts)
             |> json_response(401)
  end

  # ---------------------------------------------------------------------------
  # Garbage / tampered token
  # ---------------------------------------------------------------------------

  test "garbage bearer token returns 401 on a protected endpoint" do
    assert @unauthorized_response ==
             :get
             |> auth_conn("/api/lists", "this-is-not-a-jwt")
             |> TodexWeb.Router.call(@opts)
             |> json_response(401)
  end

  test "tampered bearer token (valid-looking JWT structure, wrong signature) returns 401" do
    # Take a valid-shaped JWT and corrupt the signature segment
    tampered = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmYWtlIn0.invalidsig"

    assert @unauthorized_response ==
             :get
             |> auth_conn("/api/auth/me", tampered)
             |> TodexWeb.Router.call(@opts)
             |> json_response(401)
  end

  # ---------------------------------------------------------------------------
  # Nonexistent email (no_user_verify path)
  # ---------------------------------------------------------------------------

  test "login_user with nonexistent email returns invalid_credentials" do
    assert {:error, :invalid_credentials} =
             Accounts.login_user(
               "nobody-#{System.unique_integer([:positive])}@example.com",
               "whatever"
             )
  end

  # ---------------------------------------------------------------------------
  # Login endpoint returns 401 for wrong credentials
  # ---------------------------------------------------------------------------

  test "POST /api/auth/login returns 401 for nonexistent user" do
    response =
      :post
      |> json_conn("/api/auth/login", %{
        email: "ghost-#{System.unique_integer([:positive])}@example.com",
        password: "password123"
      })
      |> TodexWeb.Router.call(@opts)
      |> json_response(401)

    assert %{"error" => %{"code" => "invalid_credentials"}} = response
  end
end
