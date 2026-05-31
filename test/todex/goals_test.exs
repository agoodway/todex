defmodule Todex.GoalsTest do
  use Todex.DataCase, async: true

  alias Todex.Goals
  alias Todex.Goals.GoalTask
  alias Todex.Onboarding
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

  defp task_fixture(user, list, attrs \\ %{}) do
    attrs = Map.merge(%{title: "Task", list_id: list.id}, attrs)
    assert {:ok, task, []} = Todos.create_task(user, attrs)
    task
  end

  test "create_goal persists accepted fields, scopes to the user, and ignores progress" do
    user = user_fixture("goals-create@example.com")

    assert {:ok, goal} =
             Goals.create_goal(user, %{
               "title" => "Launch goals",
               "description" => "Build the API",
               "reason" => "Track objectives",
               "progress" => 90,
               "ignored" => "field"
             })

    assert goal.user_id == user.id
    assert goal.title == "Launch goals"
    assert goal.description == "Build the API"
    assert goal.reason == "Track objectives"
    assert goal.progress == 0
  end

  test "goal operations are scoped to the owning user" do
    user = user_fixture("goals-owner@example.com")
    other_user = user_fixture("goals-other@example.com")
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Private"})

    assert Goals.get_goal(other_user, goal.id) == nil
    assert {:error, :not_found} = Goals.update_goal(other_user, goal.id, %{title: "Nope"})
    assert {:error, :not_found} = Goals.delete_goal(other_user, goal.id)
  end

  test "goal operations ignore non-map attrs instead of crashing" do
    user = user_fixture("goals-non-map@example.com")

    assert {:error, changeset} = Goals.create_goal(user, "not attrs")
    assert %{title: ["can't be blank"]} = errors_on(changeset)

    assert {:ok, goal} = Goals.create_goal(user, %{title: "Stable"})
    assert {:ok, updated_goal} = Goals.update_goal(user, goal.id, "not attrs")
    assert updated_goal.title == "Stable"
  end

  test "delete_goal removes goal task links and leaves linked tasks intact" do
    user = user_fixture("goals-delete-links@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list)
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Delete links"})
    assert {:ok, _goal} = Goals.link_task(user, goal.id, task.id)

    assert Repo.exists?(GoalTask)

    assert {:ok, _goal} = Goals.delete_goal(user, goal.id)

    refute Repo.exists?(GoalTask)
    assert Todos.get_task(user, task.id)
  end

  test "link_task is idempotent and recomputes rounded progress" do
    user = user_fixture("goals-link@example.com")
    list = list_fixture(user)
    task_a = task_fixture(user, list, %{title: "A", status: "completed"})
    task_b = task_fixture(user, list, %{title: "B"})
    task_c = task_fixture(user, list, %{title: "C"})
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Progress"})

    assert {:ok, goal} = Goals.link_task(user, goal.id, task_a.id)
    assert goal.progress == 100

    assert {:ok, goal} = Goals.link_task(user, goal.id, task_a.id)
    assert goal.progress == 100

    assert {:ok, goal} = Goals.link_task(user, goal.id, task_b.id)
    assert goal.progress == 50

    assert {:ok, goal} = Goals.link_task(user, goal.id, task_c.id)
    assert goal.progress == 33
  end

  test "unlink_task removes association and missing association returns not_found" do
    user = user_fixture("goals-unlink@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{title: "A", status: "completed"})
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Progress"})
    assert {:ok, goal} = Goals.link_task(user, goal.id, task.id)
    assert goal.progress == 100

    assert {:ok, goal} = Goals.unlink_task(user, goal.id, task.id)
    assert goal.progress == 0
    assert {:error, :not_found} = Goals.unlink_task(user, goal.id, task.id)
  end

  test "link_task rejects foreign goals and tasks" do
    user = user_fixture("goals-link-owner@example.com")
    other_user = user_fixture("goals-link-other@example.com")
    list = list_fixture(user)
    other_list = list_fixture(other_user)
    task = task_fixture(user, list)
    other_task = task_fixture(other_user, other_list)
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Mine"})
    assert {:ok, other_goal} = Goals.create_goal(other_user, %{title: "Other"})

    assert {:error, :not_found} = Goals.link_task(user, other_goal.id, task.id)
    assert {:error, :not_found} = Goals.link_task(user, goal.id, other_task.id)
  end

  test "link_task and unlink_task return not_found for missing or malformed task ids" do
    user = user_fixture("goals-invalid-task-id@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list)
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Goal"})

    assert {:error, :not_found} = Goals.link_task(user, goal.id, nil)
    assert {:error, :not_found} = Goals.link_task(user, goal.id, "not-a-uuid")
    assert {:error, :not_found} = Goals.unlink_task(user, goal.id, nil)
    assert {:error, :not_found} = Goals.unlink_task(user, goal.id, "not-a-uuid")

    assert {:ok, _goal} = Goals.link_task(user, goal.id, task.id)
  end

  test "recompute_progress accepts a list of goal ids" do
    user = user_fixture("goals-list-recompute@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{status: "completed"})
    assert {:ok, goal_a} = Goals.create_goal(user, %{title: "Goal A"})
    assert {:ok, goal_b} = Goals.create_goal(user, %{title: "Goal B"})
    assert {:ok, _goal_a} = Goals.link_task(user, goal_a.id, task.id)
    assert {:ok, _goal_b} = Goals.link_task(user, goal_b.id, task.id)

    assert {:ok, updated_goals} = Goals.recompute_progress(Repo, user, [goal_a.id, goal_b.id])

    assert Enum.map(updated_goals, & &1.id) == [goal_a.id, goal_b.id]
    assert Enum.all?(updated_goals, &(&1.progress == 100))
  end

  test "update_goal ignores client-supplied progress when derived progress is non-zero" do
    user = user_fixture("goals-ignore-progress@example.com")
    list = list_fixture(user)
    task = task_fixture(user, list, %{status: "completed"})
    assert {:ok, goal} = Goals.create_goal(user, %{title: "Goal"})
    assert {:ok, goal} = Goals.link_task(user, goal.id, task.id)
    assert goal.progress == 100

    assert {:ok, updated_goal} =
             Goals.update_goal(user, goal.id, %{progress: 12, title: "Renamed"})

    assert updated_goal.title == "Renamed"
    assert updated_goal.progress == 100
  end
end
