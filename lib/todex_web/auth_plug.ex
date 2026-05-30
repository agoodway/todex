defmodule TodexWeb.AuthPlug do
  import Plug.Conn

  alias Todex.Accounts
  alias TodexWeb.Errors

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Accounts.verify_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:auth_token, token)
    else
      _ ->
        Errors.send_error(conn, 401, "unauthorized", "Unauthorized")
    end
  end
end
