defmodule TodexWeb.Errors do
  import Plug.Conn

  require Logger

  alias Ecto.Changeset

  def json(conn, status, %{code: code, message: message} = error) do
    json(conn, status, code, message, Map.get(error, :details, %{}))
  end

  def json(conn, status, code, message, details \\ %{}) do
    body = Jason.encode!(%{error: %{code: code, message: message, details: details}})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  def send_error(conn, status, code, message, details \\ %{}) do
    conn
    |> json(status, code, message, details)
    |> halt()
  end

  def handle_error(conn, %{reason: %Plug.Parsers.ParseError{} = error}) do
    handle_error(conn, error)
  end

  def handle_error(conn, %Plug.Parsers.ParseError{}) do
    send_error(conn, 400, "invalid_json", "Invalid JSON request body")
  end

  def handle_error(conn, error) do
    Logger.error("Unhandled error at #{conn.request_path}: #{inspect(error)}")
    send_error(conn, 500, "internal_server_error", "Internal server error")
  end

  def require_json_body(conn, callback) when is_function(callback, 1) do
    if json_content_type?(conn) do
      callback.(conn)
    else
      send_error(conn, 415, "unsupported_media_type", "Content-Type must be application/json")
    end
  end

  def changeset_details(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Maps a domain error reason to user-facing error information.

  This is the single source of truth shared by both the REST interface
  (`render_result/4`, which uses `:status`, `:code`, `:message`, `:details`)
  and the WebSocket interface (`TodexWeb.Realtime.CommandHandler`, which uses
  `:code`, `:message`, `:details`).

  The second argument is an explicit contract for unknown reasons. The REST
  caller relies on the `:raise` default so unenumerated reasons fail loud
  (yielding a 500). The WebSocket caller supplies a tolerant fallback map that
  is returned verbatim for unknown reasons.
  """
  def error_info(reason, default \\ :raise)

  def error_info(%Changeset{} = changeset, _default) do
    %{
      status: 422,
      code: "validation_failed",
      message: "Validation failed",
      details: changeset_details(changeset)
    }
  end

  def error_info(:not_found, _default) do
    %{status: 404, code: "not_found", message: "Not found", details: %{}}
  end

  def error_info(:list_not_found, _default) do
    %{status: 422, code: "list_not_found", message: "List not found", details: %{}}
  end

  def error_info(:list_has_tasks, _default) do
    %{status: 422, code: "list_has_tasks", message: "List has tasks", details: %{}}
  end

  def error_info(:folder_not_found, _default) do
    %{status: 422, code: "folder_not_found", message: "Folder not found", details: %{}}
  end

  def error_info(:folder_has_notes, _default) do
    %{status: 422, code: "folder_has_notes", message: "Folder has notes", details: %{}}
  end

  def error_info(:invalid_credentials, _default) do
    %{status: 401, code: "invalid_credentials", message: "Invalid credentials", details: %{}}
  end

  def error_info(reason, :raise) do
    raise FunctionClauseError,
      module: __MODULE__,
      function: :error_info,
      arity: 2,
      args: [reason, :raise]
  end

  def error_info(_reason, default), do: default

  def render_result(conn, {:ok, value}, status, serializer) when is_function(serializer, 1) do
    response = serializer.(value)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{data: response}))
  end

  def render_result(conn, {:error, reason}, _status, _serializer) do
    %{status: status, code: code, message: message, details: details} = error_info(reason)
    send_error(conn, status, code, message, details)
  end

  defp json_content_type?(conn) do
    conn
    |> get_req_header("content-type")
    |> Enum.any?(&json_media_type?/1)
  end

  defp json_media_type?(content_type) do
    media_type =
      content_type
      |> String.split(";", parts: 2)
      |> List.first()
      |> String.trim()
      |> String.downcase()

    media_type == "application/json" or
      (String.starts_with?(media_type, "application/") and String.ends_with?(media_type, "+json"))
  end
end
