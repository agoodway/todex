defmodule TodexWeb.WebSocketHandler do
  @moduledoc """
  WebSocket event handlers for the `/api/ws` endpoint.

  Authentication uses a first-message handshake instead of a URL query param.
  On `:join` the connection starts UNAUTHENTICATED. The client must send:

      {"type": "auth", "payload": {"token": "<jwt>"}}

  On success the server replies:

      {"type": "auth_ok"}

  On failure:

      {"id": null, "type": "error", "error": {"code": "unauthorized", ...}}

  Any command received before successful auth is rejected with the same
  unauthorized error shape and is NOT dispatched to CommandHandler.

  Per-connection auth state is stored in the transport process's process
  dictionary under the key `:ws_auth` (nil = unauthenticated, map with user and
  token = authenticated). The WS process runs each handler callback, so
  `Process.put/2`/`Process.get/1` are scoped to the correct connection.
  """

  alias Todex.Accounts

  # Maximum number of FAILED auth attempts allowed per connection before
  # further auth messages are rejected without calling verify_token/1.
  #
  # NOTE (residual limitation): this caps per-connection brute force only.
  # Cross-connection (per-IP) throttling is NOT possible here because Francis
  # does not surface the remote IP to WS handlers — the socket state map only
  # carries :id/:path/:params/:transport/:heartbeat_* (no peer address). An
  # IP-keyed limiter would require patching Francis, which is out of scope.
  @max_auth_failures 5

  def handle_ws_event(:join, _socket) do
    # Connection starts unauthenticated; no URL token is read or checked.
    Process.put(:ws_auth, nil)
    # Per-connection failed-auth counter (process dict is connection-scoped).
    Process.put(:ws_auth_failures, 0)
    :noreply
  end

  def handle_ws_event({:received, message}, socket) do
    case Jason.decode(message) do
      {:ok, %{"type" => "auth", "payload" => %{"token" => token}}} ->
        handle_auth(token, socket)

      {:ok, envelope} ->
        handle_command(envelope, socket)

      {:error, %Jason.DecodeError{}} ->
        {:reply, error_response(nil, "invalid_json", "Invalid JSON")}
    end
  end

  def handle_ws_event({:close, _reason}, socket) do
    Todex.Realtime.unregister_transport(socket.transport)
  end

  defp handle_auth(token, socket) do
    cond do
      # Failed-auth cap reached: reject without doing any verify work.
      (Process.get(:ws_auth_failures) || 0) >= @max_auth_failures ->
        {:reply, error_response(nil, "unauthorized", "Unauthorized")}

      true ->
        verify_and_auth(token, socket)
    end
  end

  defp verify_and_auth(token, socket) do
    case Accounts.verify_token(token) do
      {:ok, user} ->
        Process.put(:ws_auth, %{user: user, token: token})
        # Reset the failed-auth counter on a successful authentication.
        Process.put(:ws_auth_failures, 0)
        :ok = Todex.Realtime.register(user.id, socket.transport)
        {:reply, %{type: "auth_ok"}}

      {:error, :invalid_token} ->
        clear_auth(socket)
        Process.put(:ws_auth_failures, (Process.get(:ws_auth_failures) || 0) + 1)
        {:reply, error_response(nil, "unauthorized", "Unauthorized")}
    end
  end

  defp handle_command(envelope, socket) do
    case authorized_user(socket) do
      {:error, :unauthorized} ->
        {:reply, error_response(nil, "unauthorized", "Unauthorized")}

      {:error, :revoked} ->
        {:reply, error_response(command_id(envelope), "unauthorized", "Unauthorized")}

      {:ok, user} ->
        case TodexWeb.Realtime.CommandHandler.handle(user, envelope) do
          {:ok, response, broadcasts} ->
            Enum.each(broadcasts, fn broadcast ->
              :ok = Todex.Realtime.broadcast(user.id, broadcast)
            end)

            {:reply, response}

          {:error, %{type: "error"} = response} ->
            {:reply, response}
        end
    end
  end

  defp authorized_user(socket) do
    case Process.get(:ws_auth) do
      %{user: user, token: token} ->
        case Accounts.verify_token(token) do
          {:ok, _user} ->
            {:ok, user}

          {:error, :invalid_token} ->
            clear_auth(socket)
            {:error, :revoked}
        end

      _ ->
        {:error, :unauthorized}
    end
  end

  defp clear_auth(socket) do
    case Process.get(:ws_auth) do
      %{user: user} -> Todex.Realtime.unregister(user.id, socket.transport)
      _ -> :ok
    end

    Process.put(:ws_auth, nil)
    {:error, :unauthorized}
  end

  defp error_response(id, code, message, details \\ %{}) do
    %{id: id, type: "error", error: %{code: code, message: message, details: details}}
  end

  defp command_id(envelope), do: Map.get(envelope, "id") || Map.get(envelope, :id)
end
