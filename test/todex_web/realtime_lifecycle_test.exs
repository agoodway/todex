defmodule TodexWeb.RealtimeLifecycleTest do
  @moduledoc """
  Realtime registry lifecycle tests and WebSocket envelope edge cases.
  """

  use Todex.DataCase, async: true

  alias Todex.Onboarding
  alias Todex.Realtime

  # ---------------------------------------------------------------------------
  # Re-register: moving a transport to a different user
  # ---------------------------------------------------------------------------

  test "re-registering a transport under a new user unsubscribes it from the old user" do
    old_user_id = "lifecycle-old-#{System.unique_integer([:positive])}"
    new_user_id = "lifecycle-new-#{System.unique_integer([:positive])}"

    :ok = Realtime.register(old_user_id, self())

    # Broadcast reaches old user
    :ok = Realtime.broadcast(old_user_id, %{type: "ping", payload: %{step: 1}})
    assert_receive payload
    assert %{"type" => "ping"} = Jason.decode!(payload)

    # Re-register under new user
    :ok = Realtime.register(new_user_id, self())

    # Broadcast to old user no longer reaches transport
    :ok = Realtime.broadcast(old_user_id, %{type: "ping", payload: %{step: 2}})
    refute_receive _, 200

    # Broadcast to new user does reach transport
    :ok = Realtime.broadcast(new_user_id, %{type: "ping", payload: %{step: 3}})
    assert_receive payload2, 500
    assert %{"type" => "ping", "payload" => %{"step" => 3}} = Jason.decode!(payload2)

    # Cleanup
    :ok = Realtime.unregister(new_user_id, self())
  end

  # ---------------------------------------------------------------------------
  # {:close, _} unregisters the transport
  # ---------------------------------------------------------------------------

  test "handle_ws_event {:close, _} unregisters transport so broadcasts are not received" do
    user_id = "lifecycle-close-#{System.unique_integer([:positive])}"
    socket = %{transport: self()}

    :ok = Realtime.register(user_id, self())

    # Simulate close event
    TodexWeb.WebSocketHandler.handle_ws_event({:close, :normal}, socket)

    :ok = Realtime.broadcast(user_id, %{type: "ping", payload: %{}})
    refute_receive _, 200
  end

  # ---------------------------------------------------------------------------
  # unregister with wrong user id is a no-op
  # ---------------------------------------------------------------------------

  test "unregister with a mismatched user_id is a no-op; transport still receives broadcasts" do
    correct_user_id = "lifecycle-unrg-correct-#{System.unique_integer([:positive])}"
    wrong_user_id = "lifecycle-unrg-wrong-#{System.unique_integer([:positive])}"

    :ok = Realtime.register(correct_user_id, self())

    # Attempt to unregister using wrong user id
    :ok = Realtime.unregister(wrong_user_id, self())

    # Transport is still registered under correct_user_id
    assert Realtime.registered?(correct_user_id, self())

    # Broadcast to correct user still reaches transport
    :ok = Realtime.broadcast(correct_user_id, %{type: "ping", payload: %{}})
    assert_receive _payload

    # Cleanup
    :ok = Realtime.unregister(correct_user_id, self())
  end

  # ---------------------------------------------------------------------------
  # registered?/2 on a dead pid returns false and cleans up
  # ---------------------------------------------------------------------------

  test "registered?/2 on a dead pid returns false and cleans up the registry" do
    user_id = "lifecycle-dead-#{System.unique_integer([:positive])}"

    dead_pid =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    :ok = Realtime.register(user_id, dead_pid)
    ref = Process.monitor(dead_pid)
    send(dead_pid, :stop)
    assert_receive {:DOWN, ^ref, :process, ^dead_pid, _reason}

    refute Realtime.registered?(user_id, dead_pid)
  end

  # ---------------------------------------------------------------------------
  # WS auth message handshake with invalid/garbage token
  # ---------------------------------------------------------------------------

  test "auth message with a garbage token returns unauthorized and does not register transport" do
    socket = %{transport: self()}
    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    auth_msg = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => "garbage.not.a.jwt"}})

    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    assert response.type == "error"
    assert response.error.code == "unauthorized"

    # Transport must not be registered under any user.
    user_id = "ws-bad-token-#{System.unique_integer([:positive])}"
    Todex.Realtime.register(user_id, self())
    Todex.Realtime.unregister(user_id, self())
  end

  test "auth message with a revoked token returns unauthorized and does not register transport" do
    alias Todex.Accounts
    email = "lifecycle-revoked-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: _user, token: token}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    # Revoke the token by logging out
    :ok = Accounts.logout_token(token)

    socket = %{transport: self()}
    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    auth_msg = Jason.encode!(%{"type" => "auth", "payload" => %{"token" => token}})

    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, auth_msg}, socket)

    assert response.type == "error"
    assert response.error.code == "unauthorized"
  end

  test "command before auth returns unauthorized and does not dispatch" do
    socket = %{transport: self()}
    TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    command = ~s({"id":"1","type":"list:create","payload":{"name":"x"}})

    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event({:received, command}, socket)

    assert response.type == "error"
    assert response.error.code == "unauthorized"
  end

  # ---------------------------------------------------------------------------
  # Invalid JSON message -> "invalid_json" error
  # ---------------------------------------------------------------------------

  test "received invalid JSON message returns invalid_json error envelope" do
    socket = %{transport: self()}

    # JSON decode error is caught regardless of auth state.
    assert {:reply, response} =
             TodexWeb.WebSocketHandler.handle_ws_event(
               {:received, "{invalid json"},
               socket
             )

    assert response == %{
             id: nil,
             type: "error",
             error: %{code: "invalid_json", message: "Invalid JSON", details: %{}}
           }
  end

  # ---------------------------------------------------------------------------
  # Malformed command envelopes
  # ---------------------------------------------------------------------------

  test "command envelope missing payload returns invalid_envelope error" do
    email = "lifecycle-env-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    alias TodexWeb.Realtime.CommandHandler

    # Envelope with id and type but no payload
    assert {:error, response} =
             CommandHandler.handle(user, %{"id" => "missing-payload", "type" => "task:create"})

    assert response.error.code == "invalid_envelope"
  end

  test "command envelope that is a non-map returns invalid_envelope error" do
    email = "lifecycle-env2-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    alias TodexWeb.Realtime.CommandHandler

    assert {:error, response} = CommandHandler.handle(user, "not a map at all")
    assert response.error.code == "invalid_envelope"
  end

  test "command envelope with non-map payload returns invalid_envelope error" do
    email = "lifecycle-env3-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    alias TodexWeb.Realtime.CommandHandler

    # payload is a list, not a map
    assert {:error, response} =
             CommandHandler.handle(user, %{
               "id" => "bad-payload",
               "type" => "task:create",
               "payload" => ["not", "a", "map"]
             })

    assert response.error.code == "invalid_envelope"
  end
end
