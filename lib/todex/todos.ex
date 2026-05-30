defmodule Todex.Todos do
  import Ecto.Query

  alias Todex.Repo
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
    case get_list(user, id) do
      nil ->
        {:error, :not_found}

      list ->
        list
        |> List.changeset(known_attrs(attrs, [:name, :icon, :color, :position]))
        |> Repo.update()
    end
  end

  def delete_list(user, id) do
    with %List{} = list <- get_list(user, id),
         false <- list_has_tasks?(user, list.id) do
      Repo.delete(list)
    else
      nil -> {:error, :not_found}
      true -> {:error, :list_has_tasks}
    end
  end

  def list_tasks(user, params \\ %{}) do
    Task
    |> where([task], task.user_id == ^user.id)
    |> filter_view(param(params, :view))
    |> filter_list_id(param(params, :list_id))
    |> filter_status(param(params, :status))
    |> filter_search(param(params, :q))
    |> filter_due_after(parse_filter_date(param(params, :due_after)))
    |> filter_due_before(parse_filter_date(param(params, :due_before)))
    |> order_by([task], asc_nulls_last: task.due_date, asc: task.position, asc: task.inserted_at)
    |> Repo.all()
  end

  def get_task(user, id) do
    case cast_uuid(id) do
      {:ok, id} ->
        Task
        |> where([task], task.user_id == ^user.id and task.id == ^id)
        |> Repo.one()

      :error ->
        nil
    end
  end

  def create_task(user, attrs) do
    with {:ok, attrs} <- validate_list_owner(user, attrs) do
      attrs =
        attrs
        |> known_task_attrs()
        |> Map.put(:user_id, user.id)
        |> normalize_task_attrs()

      %Task{}
      |> Task.changeset(attrs)
      |> Repo.insert()
    end
  end

  def update_task(user, id, attrs) do
    with %Task{} = task <- get_task(user, id),
         {:ok, attrs} <- validate_list_owner(user, attrs) do
      task
      |> Task.changeset(attrs |> known_task_attrs() |> normalize_task_attrs())
      |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_task(user, id) do
    case get_task(user, id) do
      nil -> {:error, :not_found}
      task -> Repo.delete(task)
    end
  end

  def complete_task(user, id) do
    update_task(user, id, %{status: :completed, completed_at: DateTime.utc_now()})
  end

  def reopen_task(user, id) do
    update_task(user, id, %{status: :active, completed_at: nil})
  end

  def get_list(user, id) do
    case cast_uuid(id) do
      {:ok, id} ->
        List
        |> where([list], list.user_id == ^user.id and list.id == ^id)
        |> Repo.one()

      :error ->
        nil
    end
  end

  defp list_has_tasks?(user, list_id) do
    Task
    |> where([task], task.user_id == ^user.id and task.list_id == ^list_id)
    |> Repo.exists?()
  end

  defp validate_list_owner(user, attrs) do
    case param(attrs, :list_id) do
      nil ->
        {:ok, attrs}

      list_id ->
        if get_list(user, list_id), do: {:ok, attrs}, else: {:error, :list_not_found}
    end
  end

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

  defp filter_list_id(query, nil), do: query

  defp filter_list_id(query, list_id) do
    case cast_uuid(list_id) do
      {:ok, list_id} -> where(query, [task], task.list_id == ^list_id)
      :error -> none(query)
    end
  end

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

  defp cast_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> {:ok, id}
      :error -> :error
    end
  end

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
