defmodule TodexWeb.ProtectedRouter do
  use Francis,
    error_handler: &TodexWeb.Errors.handle_error/2,
    parser: [parsers: [], pass: ["*/*"]]

  alias Todex.Accounts
  alias Todex.Goals
  alias Todex.Notes
  alias Todex.Todos
  alias TodexWeb.Errors
  alias TodexWeb.Json

  defp task_result({:ok, task, _affected_goals}), do: {:ok, task}
  defp task_result(result), do: result

  plug(TodexWeb.SafeParsers)
  plug(TodexWeb.AuthPlug)

  post("/auth/logout", fn conn ->
    :ok = Accounts.logout_token(conn.assigns.auth_token)
    %{data: %{ok: true}}
  end)

  get("/auth/me", fn conn ->
    %{data: %{user: Json.user(conn.assigns.current_user)}}
  end)

  get("/lists", fn conn ->
    %{data: %{lists: Enum.map(Todos.list_lists(conn.assigns.current_user), &Json.list/1)}}
  end)

  post("/lists", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        Todos.create_list(conn.assigns.current_user, conn.body_params),
        201,
        fn list ->
          %{list: Json.list(list)}
        end
      )
    end)
  end)

  get("/lists/:id", fn conn ->
    case Todos.get_list(conn.assigns.current_user, conn.params["id"]) do
      nil -> Errors.render_result(conn, {:error, :not_found}, 200, & &1)
      list -> %{data: %{list: Json.list(list)}}
    end
  end)

  patch("/lists/:id", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        Todos.update_list(conn.assigns.current_user, conn.params["id"], conn.body_params),
        200,
        fn list -> %{list: Json.list(list)} end
      )
    end)
  end)

  delete("/lists/:id", fn conn ->
    conn
    |> Errors.render_result(
      Todos.delete_list(conn.assigns.current_user, conn.params["id"]),
      200,
      fn list ->
        %{list: Json.list(list)}
      end
    )
  end)

  get("/note-folders", fn conn ->
    %{
      data: %{
        note_folders:
          conn.assigns.current_user |> Notes.list_folders() |> Enum.map(&Json.note_folder/1)
      }
    }
  end)

  post("/note-folders", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        Notes.create_folder(conn.assigns.current_user, conn.body_params),
        201,
        fn folder -> %{note_folder: Json.note_folder(folder)} end
      )
    end)
  end)

  get("/note-folders/:id", fn conn ->
    case Notes.get_folder(conn.assigns.current_user, conn.params["id"]) do
      nil -> Errors.render_result(conn, {:error, :not_found}, 200, & &1)
      folder -> %{data: %{note_folder: Json.note_folder(folder)}}
    end
  end)

  patch("/note-folders/:id", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        Notes.update_folder(conn.assigns.current_user, conn.params["id"], conn.body_params),
        200,
        fn folder -> %{note_folder: Json.note_folder(folder)} end
      )
    end)
  end)

  delete("/note-folders/:id", fn conn ->
    conn
    |> Errors.render_result(
      Notes.delete_folder(conn.assigns.current_user, conn.params["id"]),
      200,
      fn folder -> %{note_folder: Json.note_folder(folder)} end
    )
  end)

  get("/tasks", fn conn ->
    %{
      data: %{
        tasks:
          conn.assigns.current_user |> Todos.list_tasks(conn.params) |> Enum.map(&Json.task/1)
      }
    }
  end)

  post("/tasks", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        conn.assigns.current_user |> Todos.create_task(conn.body_params) |> task_result(),
        201,
        fn task ->
          %{task: Json.task(task)}
        end
      )
    end)
  end)

  get("/tasks/:id", fn conn ->
    case Todos.get_task(conn.assigns.current_user, conn.params["id"]) do
      nil -> Errors.render_result(conn, {:error, :not_found}, 200, & &1)
      task -> %{data: %{task: Json.task(task)}}
    end
  end)

  patch("/tasks/:id", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        conn.assigns.current_user
        |> Todos.update_task(conn.params["id"], conn.body_params)
        |> task_result(),
        200,
        fn task -> %{task: Json.task(task)} end
      )
    end)
  end)

  delete("/tasks/:id", fn conn ->
    conn
    |> Errors.render_result(
      conn.assigns.current_user |> Todos.delete_task(conn.params["id"]) |> task_result(),
      200,
      fn task ->
        %{task: Json.task(task)}
      end
    )
  end)

  post("/tasks/:id/complete", fn conn ->
    conn
    |> Errors.render_result(
      conn.assigns.current_user |> Todos.complete_task(conn.params["id"]) |> task_result(),
      200,
      fn task ->
        %{task: Json.task(task)}
      end
    )
  end)

  post("/tasks/:id/reopen", fn conn ->
    conn
    |> Errors.render_result(
      conn.assigns.current_user |> Todos.reopen_task(conn.params["id"]) |> task_result(),
      200,
      fn task ->
        %{task: Json.task(task)}
      end
    )
  end)

  get("/goals", fn conn ->
    %{data: %{goals: conn.assigns.current_user |> Goals.list_goals() |> Enum.map(&Json.goal/1)}}
  end)

  post("/goals", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        Goals.create_goal(conn.assigns.current_user, conn.body_params),
        201,
        fn goal -> %{goal: Json.goal(goal)} end
      )
    end)
  end)

  get("/goals/:id", fn conn ->
    case Goals.get_goal(conn.assigns.current_user, conn.params["id"]) do
      nil -> Errors.render_result(conn, {:error, :not_found}, 200, & &1)
      goal -> %{data: %{goal: Json.goal(goal)}}
    end
  end)

  patch("/goals/:id", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        Goals.update_goal(conn.assigns.current_user, conn.params["id"], conn.body_params),
        200,
        fn goal -> %{goal: Json.goal(goal)} end
      )
    end)
  end)

  delete("/goals/:id", fn conn ->
    conn
    |> Errors.render_result(
      Goals.delete_goal(conn.assigns.current_user, conn.params["id"]),
      200,
      fn goal -> %{goal: Json.goal(goal)} end
    )
  end)

  post("/goals/:id/tasks", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      task_id = Map.get(conn.body_params, "task_id") || Map.get(conn.body_params, :task_id)

      conn
      |> Errors.render_result(
        Goals.link_task(conn.assigns.current_user, conn.params["id"], task_id),
        200,
        fn goal -> %{goal: Json.goal(goal)} end
      )
    end)
  end)

  delete("/goals/:id/tasks/:task_id", fn conn ->
    conn
    |> Errors.render_result(
      Goals.unlink_task(conn.assigns.current_user, conn.params["id"], conn.params["task_id"]),
      200,
      fn goal -> %{goal: Json.goal(goal)} end
    )
  end)

  get("/notes", fn conn ->
    %{
      data: %{
        notes:
          conn.assigns.current_user |> Notes.list_notes(conn.params) |> Enum.map(&Json.note/1)
      }
    }
  end)

  post("/notes", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        Notes.create_note(conn.assigns.current_user, conn.body_params),
        201,
        fn note -> %{note: Json.note(note)} end
      )
    end)
  end)

  get("/notes/:id", fn conn ->
    case Notes.get_note(conn.assigns.current_user, conn.params["id"]) do
      nil -> Errors.render_result(conn, {:error, :not_found}, 200, & &1)
      note -> %{data: %{note: Json.note(note)}}
    end
  end)

  patch("/notes/:id", fn conn ->
    Errors.require_json_body(conn, fn conn ->
      conn
      |> Errors.render_result(
        Notes.update_note(conn.assigns.current_user, conn.params["id"], conn.body_params),
        200,
        fn note -> %{note: Json.note(note)} end
      )
    end)
  end)

  delete("/notes/:id", fn conn ->
    conn
    |> Errors.render_result(
      Notes.soft_delete_note(conn.assigns.current_user, conn.params["id"]),
      200,
      fn note -> %{note: Json.note(note)} end
    )
  end)

  post("/notes/:id/pin", fn conn ->
    conn
    |> Errors.render_result(
      Notes.pin_note(conn.assigns.current_user, conn.params["id"]),
      200,
      fn note -> %{note: Json.note(note)} end
    )
  end)

  post("/notes/:id/unpin", fn conn ->
    conn
    |> Errors.render_result(
      Notes.unpin_note(conn.assigns.current_user, conn.params["id"]),
      200,
      fn note -> %{note: Json.note(note)} end
    )
  end)

  post("/notes/:id/restore", fn conn ->
    conn
    |> Errors.render_result(
      Notes.restore_note(conn.assigns.current_user, conn.params["id"]),
      200,
      fn note -> %{note: Json.note(note)} end
    )
  end)

  delete("/notes/:id/permanent", fn conn ->
    conn
    |> Errors.render_result(
      Notes.permanently_delete_note(conn.assigns.current_user, conn.params["id"]),
      200,
      fn note -> %{note: Json.note(note)} end
    )
  end)

  unmatched(fn conn -> Errors.send_error(conn, 404, "not_found", "Not found") end)
end

defmodule TodexWeb.Router do
  use Francis,
    error_handler: &TodexWeb.Errors.handle_error/2,
    parser: [parsers: [], pass: ["*/*"]]

  alias Todex.Accounts
  alias Todex.Onboarding
  alias TodexWeb.Errors
  alias TodexWeb.Json
  alias TodexWeb.RateLimit

  plug(OpenApiSpex.Plug.PutApiSpec, module: TodexWeb.ApiSpec)
  plug(TodexWeb.SafeParsers)

  get("/", fn _conn -> %{ok: true} end)

  get("/api/openapi", fn conn ->
    if Application.get_env(:todex, :swagger_ui_enabled, false) do
      spec = Jason.encode!(TodexWeb.ApiSpec.spec())

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, spec)
    else
      Errors.send_error(conn, 404, "not_found", "Not found")
    end
  end)

  get("/swaggerui", fn conn ->
    if Application.get_env(:todex, :swagger_ui_enabled, false) do
      OpenApiSpex.Plug.SwaggerUI.call(
        conn,
        OpenApiSpex.Plug.SwaggerUI.init(path: "/api/openapi")
      )
    else
      Errors.send_error(conn, 404, "not_found", "Not found")
    end
  end)

  post("/api/auth/register", fn conn ->
    with :ok <- check_rate_limit(conn) do
      Errors.require_json_body(conn, fn conn ->
        conn
        |> Errors.render_result(Onboarding.register_user(conn.body_params), 201, fn result ->
          %{user: Json.user(result.user), token: result.token}
        end)
      end)
    end
  end)

  post("/api/auth/login", fn conn ->
    with :ok <- check_rate_limit(conn) do
      Errors.require_json_body(conn, fn conn ->
        email = Map.get(conn.body_params, "email")
        password = Map.get(conn.body_params, "password")

        conn
        |> Errors.render_result(Accounts.login_user(email, password), 200, fn %{
                                                                                user: user,
                                                                                token: token
                                                                              } ->
          %{user: Json.user(user), token: token}
        end)
      end)
    end
  end)

  ws("/api/ws", fn
    :join, socket ->
      TodexWeb.WebSocketHandler.handle_ws_event(:join, socket)

    {:received, message}, socket ->
      TodexWeb.WebSocketHandler.handle_ws_event({:received, message}, socket)

    {:close, reason}, socket ->
      TodexWeb.WebSocketHandler.handle_ws_event({:close, reason}, socket)
  end)

  forward("/api", to: TodexWeb.ProtectedRouter)

  unmatched(fn conn -> Errors.send_error(conn, 404, "not_found", "Not found") end)

  @impl true
  def start(_type, _args) do
    dev = Application.get_env(:francis, :dev, false)
    watcher_spec = if dev, do: [{Francis.Watcher, []}], else: []

    children =
      [{Bandit, [plug: __MODULE__] ++ Application.get_env(:francis, :bandit_opts, [])}] ++
        watcher_spec

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp check_rate_limit(conn) do
    case RateLimit.check(conn.remote_ip) do
      :ok -> :ok
      {:error, :rate_limited} -> Errors.send_error(conn, 429, "rate_limited", "Too many requests")
    end
  end
end
