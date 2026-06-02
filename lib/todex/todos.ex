defmodule Todex.Todos do
  import Ecto.Query

  alias Ecto.Multi
  alias Todex.Goals
  alias Todex.Repo
  alias Todex.Sharing.ListShare
  alias Todex.Todos.List
  alias Todex.Todos.Task

  @default_lists [
    %{name: "Personal", icon: "user", color: "blue", position: 0, is_default: true},
    %{name: "Work", icon: "briefcase", color: "purple", position: 1, is_default: true},
    %{name: "Fitness", icon: "heart", color: "green", position: 2, is_default: true},
    %{name: "Groceries", icon: "shopping-cart", color: "orange", position: 3, is_default: true}
  ]

  def seed_default_lists(user), do: seed_default_lists(Repo, user)

  def seed_default_lists(repo, user) do
    Enum.reduce_while(@default_lists, {:ok, []}, fn attrs, {:ok, lists} ->
      result =
        %List{}
        |> List.seed_changeset(Map.put(attrs, :user_id, user.id))
        |> repo.insert()

      case result do
        {:ok, list} -> {:cont, {:ok, [list | lists]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, lists} -> {:ok, Enum.reverse(lists)}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_lists(user) do
    List
    |> where([list], list.user_id == ^user.id)
    |> order_by([list], asc: list.position, asc: list.inserted_at)
    |> Repo.all()
  end

  def create_list(user, attrs) do
    attrs =
      attrs
      |> known_attrs([:name, :icon, :color, :position])
      |> Map.put(:user_id, user.id)

    %List{}
    |> List.changeset(attrs)
    |> Repo.insert()
  end

  def update_list(user, id, attrs) do
    case fetch_list_access(user, id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, _list, :viewer} ->
        {:error, :forbidden}

      {:ok, list, role} when role in [:owner, :editor] ->
        list
        |> List.changeset(known_attrs(attrs, [:name, :icon, :color, :position]))
        |> Repo.update()
    end
  end

  def delete_list(user, id) do
    case fetch_list_access(user, id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, _list, role} when role in [:viewer, :editor] ->
        {:error, :forbidden}

      {:ok, list, :owner} ->
        if list_has_tasks?(list) do
          {:error, :list_has_tasks}
        else
          Repo.delete(list)
        end
    end
  end

  def list_tasks(user, params \\ %{}) do
    with {:ok, query} <- task_listing_query(user, param(params, :list_id)) do
      query
      |> filter_view(param(params, :view))
      |> filter_status(param(params, :status))
      |> filter_search(param(params, :q))
      |> filter_due_after(parse_filter_date(param(params, :due_after)))
      |> filter_due_before(parse_filter_date(param(params, :due_before)))
      |> order_by([task],
        asc_nulls_last: task.due_date,
        asc: task.position,
        asc: task.inserted_at
      )
      |> Repo.all()
    else
      {:error, :not_found} -> []
    end
  end

  def get_task(user, id) do
    case fetch_task_access(user, id) do
      {:ok, task, _permission} -> task
      {:error, :not_found} -> nil
    end
  end

  def create_task(user, attrs) do
    with {:ok, attrs, owner_id} <- validate_editable_list(user, attrs) do
      attrs =
        attrs
        |> known_task_attrs()
        |> Map.put(:user_id, owner_id)
        |> normalize_task_attrs()

      %Task{}
      |> Task.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, task} -> {:ok, task, []}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  def update_task(user, id, attrs) do
    with {:ok, task, permission} <- fetch_task_access(user, id),
         :ok <- require_task_editor(permission),
         {:ok, attrs} <- validate_task_target_list(user, task, attrs) do
      owner = %{id: task.user_id}

      Multi.new()
      |> Multi.update(
        :task,
        Task.changeset(task, attrs |> known_task_attrs() |> normalize_task_attrs())
      )
      |> Multi.run(:affected_goal_ids, fn repo, _changes ->
        {:ok, Goals.linked_goal_ids_for_task(repo, owner, task.id)}
      end)
      |> Multi.run(:affected_goals, fn repo, %{affected_goal_ids: affected_goal_ids} ->
        Goals.recompute_progress(repo, owner, affected_goal_ids)
      end)
      |> Repo.transaction()
      |> task_write_result()
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_task(user, id) do
    case fetch_task_access(user, id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, _task, :viewer} ->
        {:error, :forbidden}

      {:ok, task, permission} when permission in [:owner, :editor] ->
        owner = %{id: task.user_id}

        Multi.new()
        |> Multi.run(:affected_goal_ids, fn repo, _changes ->
          {:ok, Goals.linked_goal_ids_for_task(repo, owner, task.id)}
        end)
        |> Multi.delete(:task, task)
        |> Multi.run(:affected_goals, fn repo, %{affected_goal_ids: affected_goal_ids} ->
          Goals.recompute_progress(repo, owner, affected_goal_ids)
        end)
        |> Repo.transaction()
        |> task_write_result()
    end
  end

  def complete_task(user, id) do
    update_task(user, id, %{status: :completed, completed_at: DateTime.utc_now()})
  end

  def reopen_task(user, id) do
    update_task(user, id, %{status: :active, completed_at: nil})
  end

  def get_list(user, id) do
    case fetch_list_access(user, id) do
      {:ok, list, _permission} -> list
      {:error, :not_found} -> nil
    end
  end

  defp list_has_tasks?(list) do
    Task
    |> where([task], task.user_id == ^list.user_id and task.list_id == ^list.id)
    |> Repo.exists?()
  end

  defp task_write_result({:ok, %{task: task, affected_goals: affected_goals}}) do
    {:ok, task, affected_goals}
  end

  defp task_write_result({:error, _operation, reason, _changes}), do: {:error, reason}

  defp validate_editable_list(user, attrs) do
    case param(attrs, :list_id) do
      nil ->
        {:ok, attrs, user.id}

      list_id ->
        case fetch_list_access(user, list_id) do
          {:ok, list, role} when role in [:owner, :editor] -> {:ok, attrs, list.user_id}
          {:ok, _list, :viewer} -> {:error, :forbidden}
          {:error, :not_found} -> {:error, :list_not_found}
        end
    end
  end

  defp validate_task_target_list(user, task, attrs) do
    case param(attrs, :list_id) do
      nil ->
        {:ok, attrs}

      list_id ->
        case fetch_list_access(user, list_id) do
          {:ok, %{user_id: owner_id}, role}
          when role in [:owner, :editor] and owner_id == task.user_id ->
            {:ok, attrs}

          {:ok, _list, :viewer} ->
            {:error, :forbidden}

          {:ok, _list, _role} ->
            {:error, :list_not_found}

          {:error, :not_found} ->
            {:error, :list_not_found}
        end
    end
  end

  defp require_task_editor(permission) when permission in [:owner, :editor], do: :ok
  defp require_task_editor(:viewer), do: {:error, :forbidden}

  defp fetch_list_access(user, id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         {%List{} = list, role} <- list_access_query(user, id) |> Repo.one() do
      {:ok, list, list_permission(user, list, role)}
    else
      nil -> {:error, :not_found}
      :error -> {:error, :not_found}
    end
  end

  defp list_access_query(user, id) do
    List
    |> join(:left, [list], share in ListShare,
      on: share.list_id == list.id and share.recipient_id == ^user.id
    )
    |> where(
      [list, share],
      list.id == ^id and (list.user_id == ^user.id or not is_nil(share.id))
    )
    |> select([list, share], {list, share.role})
  end

  defp list_permission(user, list, _role) when list.user_id == user.id, do: :owner
  defp list_permission(_user, _list, role), do: role

  defp task_listing_query(user, nil) do
    {:ok, where(Task, [task], task.user_id == ^user.id)}
  end

  defp task_listing_query(user, list_id) do
    case fetch_list_access(user, list_id) do
      {:ok, list, _permission} ->
        query = where(Task, [task], task.user_id == ^list.user_id and task.list_id == ^list.id)
        {:ok, query}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp fetch_task_access(user, id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         {%Task{} = task, owner_id, role} <- task_access_query(user, id) |> Repo.one() do
      {:ok, task, task_permission(user, owner_id, role)}
    else
      nil -> {:error, :not_found}
      :error -> {:error, :not_found}
    end
  end

  defp task_access_query(user, id) do
    Task
    |> join(:inner, [task], list in List,
      on: list.id == task.list_id and list.user_id == task.user_id
    )
    |> join(:left, [task, list], share in ListShare,
      on: share.list_id == list.id and share.recipient_id == ^user.id
    )
    |> where(
      [task, _list, share],
      task.id == ^id and (task.user_id == ^user.id or not is_nil(share.id))
    )
    |> select([task, list, share], {task, list.user_id, share.role})
  end

  defp task_permission(user, owner_id, _role) when owner_id == user.id, do: :owner
  defp task_permission(_user, _owner_id, role), do: role

  defp filter_view(query, "today") do
    today = Date.utc_today()

    query
    |> where([task], task.status == :active)
    |> where([task], task.due_date == ^today)
  end

  defp filter_view(query, "upcoming") do
    today = Date.utc_today()

    query
    |> where([task], task.status == :active)
    |> where([task], task.due_date > ^today)
  end

  defp filter_view(query, "completed") do
    where(query, [task], task.status == :completed)
  end

  defp filter_view(query, _view), do: query

  defp filter_status(query, status) when status in ["active", :active] do
    where(query, [task], task.status == :active)
  end

  defp filter_status(query, status) when status in ["completed", :completed] do
    where(query, [task], task.status == :completed)
  end

  defp filter_status(query, _status), do: query

  defp filter_search(query, q) when is_binary(q) do
    q = String.trim(q)

    if q == "" do
      query
    else
      escaped =
        q
        |> String.replace("\\", "\\\\")
        |> String.replace("%", "\\%")
        |> String.replace("_", "\\_")

      pattern = "%#{escaped}%"

      where(
        query,
        [task],
        fragment("? ILIKE ? ESCAPE '\\'", task.title, ^pattern) or
          fragment("? ILIKE ? ESCAPE '\\'", task.notes, ^pattern)
      )
    end
  end

  defp filter_search(query, _q), do: query

  defp filter_due_after(query, :invalid), do: none(query)
  defp filter_due_after(query, %Date{} = date), do: where(query, [task], task.due_date >= ^date)
  defp filter_due_after(query, _date), do: query

  defp filter_due_before(query, :invalid), do: none(query)
  defp filter_due_before(query, %Date{} = date), do: where(query, [task], task.due_date <= ^date)
  defp filter_due_before(query, _date), do: query

  defp parse_filter_date(nil), do: nil
  defp parse_filter_date(%Date{} = date), do: date

  defp parse_filter_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> :invalid
    end
  end

  defp parse_filter_date(_value), do: :invalid

  defp normalize_task_attrs(attrs) do
    attrs
    |> put_known_if_present(:due_date, parse_date(param(attrs, :due_date)))
    |> put_known_if_present(:completed_at, parse_datetime(param(attrs, :completed_at)))
  end

  defp put_known_if_present(attrs, key, nil) do
    if has_known_key?(attrs, key), do: put_known(attrs, key, nil), else: attrs
  end

  defp put_known_if_present(attrs, key, value), do: put_known(attrs, key, value)

  defp parse_date(%Date{} = date), do: date

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> value
    end
  end

  defp parse_date(value), do: value

  defp parse_datetime(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> DateTime.truncate(datetime, :second)
      {:error, _reason} -> value
    end
  end

  defp parse_datetime(value), do: value

  defp param(attrs, key) when is_map(attrs) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end

  defp param(_attrs, _key), do: nil

  defp none(query), do: where(query, false)

  defp known_task_attrs(attrs) do
    known_attrs(attrs, [:list_id, :title, :notes, :status, :due_date, :completed_at, :position])
  end

  defp known_attrs(attrs, keys) when is_map(attrs) do
    Enum.reduce(keys, %{}, fn key, acc ->
      cond do
        Map.has_key?(attrs, key) ->
          Map.put(acc, key, Map.fetch!(attrs, key))

        Map.has_key?(attrs, Atom.to_string(key)) ->
          Map.put(acc, key, Map.fetch!(attrs, Atom.to_string(key)))

        true ->
          acc
      end
    end)
  end

  defp known_attrs(_attrs, _keys), do: %{}

  defp put_known(attrs, key, value) when is_map(attrs), do: Map.put(attrs, key, value)

  defp has_known_key?(attrs, key) when is_map(attrs) do
    Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))
  end
end
