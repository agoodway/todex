defmodule Todex.Realtime do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, initial_state(), name: __MODULE__)

  @impl true
  def init(state), do: {:ok, state}

  def register(user_id, transport) do
    GenServer.call(__MODULE__, {:register, user_id, transport})
  end

  def unregister(user_id, transport) do
    GenServer.call(__MODULE__, {:unregister, user_id, transport})
  end

  def unregister_transport(transport) do
    GenServer.call(__MODULE__, {:unregister_transport, transport})
  end

  def broadcast(user_id, event) do
    case Jason.encode(event) do
      {:ok, payload} ->
        GenServer.cast(__MODULE__, {:broadcast, user_id, payload})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def registered?(user_id, transport) do
    GenServer.call(__MODULE__, {:registered?, user_id, transport})
  end

  @impl true
  def handle_call({:register, user_id, transport}, _from, state) do
    state =
      state
      |> remove_transport(transport)
      |> put_transport(user_id, transport)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister, user_id, transport}, _from, state) do
    state =
      case Map.get(state.transports, transport) do
        ^user_id -> remove_transport(state, transport)
        _other_user_id -> state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister_transport, transport}, _from, state) do
    {:reply, :ok, remove_transport(state, transport)}
  end

  @impl true
  def handle_call({:registered?, user_id, transport}, _from, state) do
    if dead_pid?(transport) do
      {:reply, false, remove_transport(state, transport)}
    else
      {:reply, Map.get(state.transports, transport) == user_id, state}
    end
  end

  @impl true
  def handle_cast({:broadcast, user_id, payload}, state) do
    state.users
    |> Map.get(user_id, MapSet.new())
    |> Enum.each(&send(&1, payload))

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.get(state.monitors, ref) do
      nil ->
        {:noreply, state}

      transport ->
        {:noreply, remove_transport(state, transport)}
    end
  end

  defp initial_state do
    %{users: %{}, transports: %{}, monitors: %{}, transport_refs: %{}}
  end

  defp put_transport(state, user_id, transport) do
    transports = state.users |> Map.get(user_id, MapSet.new()) |> MapSet.put(transport)

    {ref, state} = monitor_transport(state, transport)

    state
    |> put_in([:users, user_id], transports)
    |> put_in([:transports, transport], user_id)
    |> put_monitor_ref(transport, ref)
  end

  defp remove_transport(state, transport) do
    case Map.get(state.transports, transport) do
      nil ->
        state

      user_id ->
        user_transports =
          state.users
          |> Map.get(user_id, MapSet.new())
          |> MapSet.delete(transport)

        state
        |> remove_user_transport(user_id, user_transports)
        |> update_in([:transports], &Map.delete(&1, transport))
        |> remove_monitor(transport)
    end
  end

  defp remove_user_transport(state, user_id, transports) do
    if MapSet.size(transports) == 0,
      do: update_in(state.users, &Map.delete(&1, user_id)),
      else: put_in(state.users[user_id], transports)
  end

  defp monitor_transport(state, transport) when is_pid(transport) do
    ref = Process.monitor(transport)
    {ref, state}
  end

  defp monitor_transport(state, _transport), do: {nil, state}

  defp dead_pid?(transport) when is_pid(transport), do: not Process.alive?(transport)
  defp dead_pid?(_transport), do: false

  defp put_monitor_ref(state, _transport, nil), do: state

  defp put_monitor_ref(state, transport, ref) do
    state
    |> put_in([:monitors, ref], transport)
    |> put_in([:transport_refs, transport], ref)
  end

  defp remove_monitor(state, transport) do
    case Map.get(state.transport_refs, transport) do
      nil ->
        state

      ref ->
        Process.demonitor(ref, [:flush])

        state
        |> update_in([:monitors], &Map.delete(&1, ref))
        |> update_in([:transport_refs], &Map.delete(&1, transport))
    end
  end
end
