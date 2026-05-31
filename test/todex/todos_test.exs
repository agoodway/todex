defmodule Todex.TodosTest do
  use Todex.DataCase, async: true

  alias Todex.Onboarding
  alias Todex.Goals
  alias Todex.Goals.GoalTask
  alias Todex.Repo
  alias Todex.Todos

  defp user_fixture(email) do
    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    user
  end

  defp list_fixture(user, attrs \\ %{}) do
    attrs = Map.merge(%{name: "Errands", position: 10}, attrs)
    assert {:ok, list} = Todos.create_list(user, attrs)
    list
  end

  defp task_fixture(user, list, attrs) do
    attrs = Map.merge(%{title: "Task", list_id: list.id}, attrs)
    assert {:ok, task, []} = Todos.create_task(user, attrs)
    task
  end

  test "create_task returns the task and an empty affected goals list" do
    user = user_fixture("task-create-result@example.com")
    list = list_fixture(user)

    assert {:ok, task, affected_goals} =
             Todos.create_task(user, %{title: "Create result", list_id: list.id})

    assert task.title == "Create result"
    assert affected_goals == []
  end

  test "create_list creates a custom list for a user" do
    user = user_fixture("lists@example.com")

    assert {:ok, list} =
             Todos.create_list(user, %{"name" => "Home", "icon" => "house", "color" => "red"})

    assert list.user_id == user.id
    assert list.name == "Home"
    assert list.icon == "house"
    assert list.color == "red"
    refute list.is_default
  end

  test "create_list ignores client-supplied is_default" do
    user = user_fixture("list-default-create@example.com")

    assert {:ok, list} =
             Todos.create_list(user, %{"name" => "Forged default", "is_default" => true})

    refute list.is_default
  end

  test "create_task rejects a list from another user" do
    user = user_fixture("owner@example.com")
    other_user = user_fixture("other-owner@example.com")
    other_list = list_fixture(other_user, %{name: "Other list"})

    assert {:error, :list_not_found} =
             Todos.create_task(user, %{title: "Nope", list_id: other_list.id})
  end

  test "update_list persists changed fields" do
    user = user_fixture("update-list@example.com")
    list = list_fixture(user, %{name: "Before", icon: "inbox", color: "gray", position: 4})

    assert {:ok, updated_list} =
             Todos.update_list(user, list.id, %{
               "name" => "After",
               "icon" => "sparkles",
               "color" => "yellow",
               "position" => 1
             })

    assert updated_list.name == "After"
    assert updated_list.icon == "sparkles"
    assert updated_list.color == "yellow"
    assert updated_list.position == 1

    assert [persisted_list] = Enum.filter(Todos.list_lists(user), &(&1.id == list.id))
    assert persisted_list.name == "After"
    assert persisted_list.icon == "sparkles"
    assert persisted_list.color == "yellow"
    assert persisted_list.position == 1
  end

  test "update_list ignores client-supplied is_default" do
    user = user_fixture("list-default-update@example.com")
    list = list_fixture(user, %{name: "Custom"})

    assert {:ok, updated_list} = Todos.update_list(user, list.id, %{"is_default" => true})

    refute updated_list.is_default
    persisted_list = Enum.find(Todos.list_lists(user), &(&1.id == list.id))
    refute persisted_list.is_default
  end

  test "update_task persists title, notes, status, and due_date updates" do
    user = user_fixture("update-task@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{title: "Before", notes: "old", due_date: Date.utc_today()})
    due_date = Date.utc_today() |> Date.add(5)

    assert {:ok, updated_task, affected_goals} =
             Todos.update_task(user, task.id, %{
               "title" => "After",
               "notes" => "new notes",
               "status" => "completed",
               "due_date" => Date.to_iso8601(due_date)
             })

    assert affected_goals == []
    assert updated_task.title == "After"
    assert updated_task.notes == "new notes"
    assert updated_task.status == :completed
    assert updated_task.due_date == due_date

    persisted_task = Todos.get_task(user, task.id)
    assert persisted_task.title == "After"
    assert persisted_task.notes == "new notes"
    assert persisted_task.status == :completed
    assert persisted_task.due_date == due_date
  end

  test "complete_task sets completed status and completed_at, then reopen_task clears them" do
    user = user_fixture("complete-reopen@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{title: "Toggle"})

    assert {:ok, completed_task, completed_goals} = Todos.complete_task(user, task.id)
    assert completed_goals == []
    assert completed_task.status == :completed
    assert %DateTime{} = completed_task.completed_at

    completed_task = Todos.get_task(user, task.id)
    assert completed_task.status == :completed
    assert %DateTime{} = completed_task.completed_at

    assert {:ok, reopened_task, reopened_goals} = Todos.reopen_task(user, task.id)
    assert reopened_goals == []
    assert reopened_task.status == :active
    assert is_nil(reopened_task.completed_at)

    reopened_task = Todos.get_task(user, task.id)
    assert reopened_task.status == :active
    assert is_nil(reopened_task.completed_at)
  end

  test "task operations return not_found for invalid task ids" do
    user = user_fixture("invalid-task-id@example.com")

    assert nil == Todos.get_task(user, "not-a-uuid")
    assert {:error, :not_found} = Todos.update_task(user, "not-a-uuid", %{title: "Changed"})
    assert {:error, :not_found} = Todos.delete_task(user, "not-a-uuid")
    assert {:error, :not_found} = Todos.complete_task(user, "not-a-uuid")
    assert {:error, :not_found} = Todos.reopen_task(user, "not-a-uuid")
  end

  test "list_tasks returns an empty list for invalid list_id filters" do
    user = user_fixture("invalid-list-filter@example.com")
    list = list_fixture(user)
    _task = task_fixture(user, list, %{title: "Visible"})

    assert [] == Todos.list_tasks(user, %{list_id: "not-a-uuid"})
  end

  test "create_task returns list_not_found for invalid list_id" do
    user = user_fixture("invalid-create-list@example.com")

    assert {:error, :list_not_found} =
             Todos.create_task(user, %{title: "No list", list_id: "not-a-uuid"})
  end

  test "list_tasks returns an empty list for invalid due_after and due_before filters" do
    user = user_fixture("invalid-due-filter@example.com")
    list = list_fixture(user)
    _task = task_fixture(user, list, %{title: "Dated", due_date: Date.utc_today()})

    assert [] == Todos.list_tasks(user, %{due_after: "not-a-date"})
    assert [] == Todos.list_tasks(user, %{due_before: "not-a-date"})
  end

  test "list_tasks filters today, upcoming, completed, search, list, status, and date range" do
    user = user_fixture("filters@example.com")
    list = list_fixture(user, %{name: "Focused"})
    other_list = list_fixture(user, %{name: "Separate"})
    today = Date.utc_today()

    today_task =
      task_fixture(user, list, %{
        title: "Buy milk",
        notes: "whole milk",
        due_date: Date.to_iso8601(today),
        position: 2
      })

    upcoming_task =
      task_fixture(user, list, %{
        title: "Book dentist",
        due_date: Date.add(today, 2),
        position: 1
      })

    completed_task =
      task_fixture(user, list, %{
        title: "File taxes",
        status: "completed",
        due_date: Date.add(today, -1),
        completed_at: "#{Date.to_iso8601(today)}T10:00:00Z"
      })

    other_list_task =
      task_fixture(user, other_list, %{
        title: "Other list task",
        due_date: Date.add(today, 4)
      })

    assert Enum.map(Todos.list_tasks(user, %{view: "today"}), & &1.id) == [today_task.id]

    assert Enum.map(Todos.list_tasks(user, %{view: "upcoming"}), & &1.id) == [
             upcoming_task.id,
             other_list_task.id
           ]

    assert Enum.map(Todos.list_tasks(user, %{view: "completed"}), & &1.id) == [completed_task.id]
    assert Enum.map(Todos.list_tasks(user, %{q: "milk"}), & &1.id) == [today_task.id]

    assert Enum.map(Todos.list_tasks(user, %{list_id: list.id, status: :active}), & &1.id) == [
             today_task.id,
             upcoming_task.id
           ]

    assert Enum.map(
             Todos.list_tasks(user, %{
               due_after: Date.to_iso8601(today),
               due_before: Date.to_iso8601(Date.add(today, 3))
             }),
             & &1.id
           ) == [today_task.id, upcoming_task.id]
  end

  test "delete_list rejects lists with tasks and succeeds after tasks are deleted" do
    user = user_fixture("delete-list@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{title: "Keep list"})

    assert {:error, :list_has_tasks} = Todos.delete_list(user, list.id)

    assert {:ok, _task, []} = Todos.delete_task(user, task.id)
    assert {:ok, _list} = Todos.delete_list(user, list.id)
    refute Enum.any?(Todos.list_lists(user), &(&1.id == list.id))
  end

  test "task operations are scoped to the owning user" do
    user = user_fixture("task-owner@example.com")
    other_user = user_fixture("task-other@example.com")
    list = list_fixture(user)
    other_list = list_fixture(other_user, %{name: "Other"})
    task = task_fixture(user, list, %{title: "Private"})

    assert nil == Todos.get_task(other_user, task.id)
    assert {:error, :not_found} = Todos.update_task(other_user, task.id, %{title: "Changed"})
    assert {:error, :not_found} = Todos.delete_task(other_user, task.id)
    assert {:error, :not_found} = Todos.complete_task(other_user, task.id)
    assert {:error, :not_found} = Todos.reopen_task(other_user, task.id)

    assert {:error, :list_not_found} = Todos.update_task(user, task.id, %{list_id: other_list.id})
  end

  test "complete and reopen recompute linked goals and return affected goals explicitly" do
    user = user_fixture("task-goal-complete@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{title: "Move progress"})
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Goal"})
    assert {:ok, goal} = Goals.link_task(user, goal.id, task.id)
    goal_id = goal.id
    assert goal.progress == 0

    assert {:ok, completed_task, completed_goals} = Todos.complete_task(user, task.id)
    assert completed_task.status == :completed
    assert [%{id: ^goal_id, progress: 100}] = completed_goals
    assert Goals.get_goal(user, goal.id).progress == 100

    assert {:ok, reopened_task, reopened_goals} = Todos.reopen_task(user, task.id)
    assert reopened_task.status == :active
    assert [%{id: ^goal_id, progress: 0}] = reopened_goals
    assert Goals.get_goal(user, goal.id).progress == 0
  end

  test "delete_task recomputes previously linked goals, returns affected goals, and removes links" do
    user = user_fixture("task-goal-delete@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{title: "Delete progress", status: "completed"})
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Goal"})
    assert {:ok, goal} = Goals.link_task(user, goal.id, task.id)
    goal_id = goal.id
    assert goal.progress == 100

    assert Repo.exists?(GoalTask)

    assert {:ok, deleted_task, deleted_goals} = Todos.delete_task(user, task.id)
    assert deleted_task.id == task.id
    assert [%{id: ^goal_id, progress: 0}] = deleted_goals
    assert Goals.get_goal(user, goal.id).progress == 0
    refute Repo.exists?(GoalTask)
  end

  test "update_task recomputes linked goals when completion state changes" do
    user = user_fixture("task-goal-update@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{title: "Update progress"})
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Goal"})
    assert {:ok, _goal} = Goals.link_task(user, goal.id, task.id)
    goal_id = goal.id

    assert {:ok, updated_task, affected_goals} =
             Todos.update_task(user, task.id, %{
               status: "completed",
               completed_at: DateTime.utc_now()
             })

    assert updated_task.status == :completed
    assert [%{id: ^goal_id, progress: 100}] = affected_goals
  end

  test "task writes affecting no goals return an empty affected goals list" do
    user = user_fixture("task-goal-empty@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{title: "No goals"})

    assert {:ok, completed_task, affected_goals} = Todos.complete_task(user, task.id)
    assert completed_task.status == :completed
    assert affected_goals == []
  end
end
