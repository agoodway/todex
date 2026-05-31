defmodule Todex.Goals do
  import Ecto.Query

  alias Ecto.Multi
  alias Todex.Goals.Goal
  alias Todex.Goals.GoalTask
  alias Todex.Repo
  alias Todex.Todos.Task

  def list_goals(user) do
    Goal
    |> where([goal], goal.user_id == ^user.id)
    |> order_by([goal], asc: goal.inserted_at)
    |> Repo.all()
  end

  def get_goal(user, id) do
    with {:ok, id} <- Ecto.UUID.cast(id) do
      Goal
      |> where([goal], goal.user_id == ^user.id and goal.id == ^id)
      |> Repo.one()
    else
      :error -> nil
    end
  end

  def create_goal(user, attrs) do
    attrs =
      attrs
      |> known_attrs([:title, :description, :reason])
      |> Map.put(:user_id, user.id)

    %Goal{}
    |> Goal.changeset(attrs)
    |> Repo.insert()
  end

  def update_goal(user, id, attrs) do
    case get_goal(user, id) do
      nil ->
        {:error, :not_found}

      goal ->
        goal
        |> Goal.changeset(known_attrs(attrs, [:title, :description, :reason]))
        |> Repo.update()
    end
  end

  def delete_goal(user, id) do
    case get_goal(user, id) do
      nil -> {:error, :not_found}
      goal -> Repo.delete(goal)
    end
  end

  def link_task(user, goal_id, task_id) do
    Multi.new()
    |> Multi.run(:goal, fn repo, _changes -> fetch_goal(repo, user, goal_id, lock: true) end)
    |> Multi.run(:task, fn repo, _changes -> fetch_task(repo, user, task_id) end)
    |> Multi.insert(
      :goal_task,
      fn %{goal: goal, task: task} ->
        GoalTask.changeset(%GoalTask{}, %{user_id: user.id, goal_id: goal.id, task_id: task.id})
      end,
      on_conflict: :nothing,
      conflict_target: [:goal_id, :task_id]
    )
    |> Multi.run(:updated_goal, fn repo, %{goal: goal} ->
      recompute_progress(repo, user, goal.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{updated_goal: goal}} -> {:ok, goal}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def unlink_task(user, goal_id, task_id) do
    Multi.new()
    |> Multi.run(:goal, fn repo, _changes -> fetch_goal(repo, user, goal_id, lock: true) end)
    |> Multi.run(:task, fn repo, _changes -> fetch_task(repo, user, task_id) end)
    |> Multi.run(:goal_task, fn repo, %{goal: goal, task: task} ->
      fetch_goal_task(repo, user, goal.id, task.id)
    end)
    |> Multi.delete(:deleted_goal_task, fn %{goal_task: goal_task} -> goal_task end)
    |> Multi.run(:updated_goal, fn repo, %{goal: goal} ->
      recompute_progress(repo, user, goal.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{updated_goal: goal}} -> {:ok, goal}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def recompute_progress(user, goal_id) do
    Repo.transaction(fn ->
      case recompute_progress(Repo, user, goal_id) do
        {:ok, goal} -> goal
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def recompute_progress(repo, user, goal_ids) when is_list(goal_ids) do
    goal_ids = Enum.uniq(goal_ids)

    goals = lock_goals(repo, user, goal_ids)

    if length(goals) != length(goal_ids) do
      {:error, :not_found}
    else
      progress_by_goal_id = progress_by_goal_id(repo, user, goal_ids)

      Enum.reduce_while(goals, {:ok, []}, fn goal, {:ok, updated_goals} ->
        progress = Map.get(progress_by_goal_id, goal.id, 0)

        case repo.update(Ecto.Changeset.change(goal, progress: progress)) do
          {:ok, updated_goal} -> {:cont, {:ok, [updated_goal | updated_goals]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, updated_goals} -> {:ok, Enum.reverse(updated_goals)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def recompute_progress(repo, user, goal_id) do
    case recompute_progress(repo, user, [goal_id]) do
      {:ok, [goal]} -> {:ok, goal}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def linked_goals_for_task(user, task_id) do
    with {:ok, task_id} <- Ecto.UUID.cast(task_id) do
      Goal
      |> join(:inner, [goal], goal_task in GoalTask, on: goal_task.goal_id == goal.id)
      |> where(
        [goal, goal_task],
        goal.user_id == ^user.id and goal_task.user_id == ^user.id and
          goal_task.task_id == ^task_id
      )
      |> order_by([goal], asc: goal.inserted_at)
      |> Repo.all()
    else
      :error -> []
    end
  end

  def linked_goal_ids_for_task(repo, user, task_id) do
    with {:ok, task_id} <- Ecto.UUID.cast(task_id) do
      Goal
      |> join(:inner, [goal], goal_task in GoalTask, on: goal_task.goal_id == goal.id)
      |> where(
        [goal, goal_task],
        goal.user_id == ^user.id and goal_task.user_id == ^user.id and
          goal_task.task_id == ^task_id
      )
      |> order_by([goal], asc: goal.inserted_at)
      |> lock("FOR UPDATE")
      |> select([goal], goal.id)
      |> repo.all()
    else
      :error -> []
    end
  end

  defp fetch_goal(repo, user, id, opts) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Goal{} = goal <-
           Goal
           |> where([goal], goal.user_id == ^user.id and goal.id == ^id)
           |> maybe_lock(opts[:lock])
           |> repo.one() do
      {:ok, goal}
    else
      _ -> {:error, :not_found}
    end
  end

  defp fetch_task(repo, user, id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Task{} = task <-
           Task
           |> where([task], task.user_id == ^user.id and task.id == ^id)
           |> repo.one() do
      {:ok, task}
    else
      _ -> {:error, :not_found}
    end
  end

  defp fetch_goal_task(repo, user, goal_id, task_id) do
    case get_goal_task(repo, user, goal_id, task_id) do
      %GoalTask{} = goal_task -> {:ok, goal_task}
      nil -> {:error, :not_found}
    end
  end

  defp get_goal_task(repo, user, goal_id, task_id) do
    GoalTask
    |> where(
      [goal_task],
      goal_task.user_id == ^user.id and goal_task.goal_id == ^goal_id and
        goal_task.task_id == ^task_id
    )
    |> repo.one()
  end

  defp lock_goals(repo, user, goal_ids) do
    Goal
    |> where([goal], goal.user_id == ^user.id and goal.id in ^goal_ids)
    |> order_by([goal], asc: goal.inserted_at)
    |> lock("FOR UPDATE")
    |> repo.all()
  end

  defp progress_by_goal_id(_repo, _user, []), do: %{}

  defp progress_by_goal_id(repo, user, goal_ids) do
    GoalTask
    |> join(:inner, [goal_task], task in Task, on: task.id == goal_task.task_id)
    |> where(
      [goal_task, task],
      goal_task.user_id == ^user.id and task.user_id == ^user.id and
        goal_task.goal_id in ^goal_ids
    )
    |> group_by([goal_task], goal_task.goal_id)
    |> select([goal_task, task], {
      goal_task.goal_id,
      fragment(
        "round((count(?) FILTER (WHERE ? = 'completed'))::numeric / count(?) * 100)::integer",
        task.id,
        task.status,
        task.id
      )
    })
    |> repo.all()
    |> Map.new()
  end

  defp maybe_lock(query, true), do: lock(query, "FOR UPDATE")
  defp maybe_lock(query, _lock), do: query

  defp known_attrs(attrs, allowed) when is_map(attrs) do
    Enum.reduce(allowed, %{}, fn key, acc ->
      string_key = Atom.to_string(key)

      cond do
        Map.has_key?(attrs, key) -> Map.put(acc, key, Map.fetch!(attrs, key))
        Map.has_key?(attrs, string_key) -> Map.put(acc, key, Map.fetch!(attrs, string_key))
        true -> acc
      end
    end)
  end

  defp known_attrs(_attrs, _allowed), do: %{}
end
