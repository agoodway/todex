defmodule TodexWeb.Schemas do
  alias OpenApiSpex.Schema

  defmodule User do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "User",
      type: :object,
      required: [:id, :email, :inserted_at, :updated_at],
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        email: %Schema{type: :string, format: :email},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule List do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "List",
      type: :object,
      required: [:id, :name, :position, :is_default, :inserted_at, :updated_at],
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        icon: %Schema{type: :string, nullable: true},
        color: %Schema{type: :string, nullable: true},
        position: %Schema{type: :integer},
        is_default: %Schema{type: :boolean},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule Task do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Task",
      type: :object,
      required: [:id, :list_id, :title, :status, :position, :inserted_at, :updated_at],
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        list_id: %Schema{type: :string, format: :uuid},
        title: %Schema{type: :string},
        notes: %Schema{type: :string, nullable: true},
        status: %Schema{type: :string, enum: ["active", "completed"]},
        due_date: %Schema{type: :string, format: :date, nullable: true},
        completed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        position: %Schema{type: :integer},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule Goal do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Goal",
      type: :object,
      required: [:id, :title, :progress, :inserted_at, :updated_at],
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        title: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        reason: %Schema{type: :string, nullable: true},
        progress: %Schema{type: :integer, minimum: 0, maximum: 100},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule NoteFolder do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NoteFolder",
      type: :object,
      required: [:id, :name, :position, :is_default, :inserted_at, :updated_at],
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        position: %Schema{type: :integer},
        is_default: %Schema{type: :boolean},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule Note do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Note",
      type: :object,
      required: [:id, :folder_id, :title, :pinned, :position, :inserted_at, :updated_at],
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        folder_id: %Schema{type: :string, format: :uuid},
        title: %Schema{type: :string},
        body: %Schema{type: :string, nullable: true},
        pinned: %Schema{type: :boolean},
        position: %Schema{type: :integer},
        deleted_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule AuthResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AuthResponse",
      type: :object,
      required: [:user, :token],
      properties: %{
        user: User,
        token: %Schema{type: :string}
      }
    })
  end

  defmodule ErrorResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      type: :object,
      required: [:error],
      properties: %{
        error: %Schema{
          type: :object,
          required: [:code, :message, :details],
          properties: %{
            code: %Schema{type: :string},
            message: %Schema{type: :string},
            details: %Schema{type: :object, additionalProperties: true}
          }
        }
      }
    })
  end

  defmodule RegisterRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "RegisterRequest",
      type: :object,
      required: [:email, :password],
      properties: %{
        email: %Schema{type: :string, format: :email},
        password: %Schema{type: :string, minLength: 8}
      }
    })
  end

  defmodule LoginRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "LoginRequest",
      type: :object,
      required: [:email, :password],
      properties: %{
        email: %Schema{type: :string, format: :email},
        password: %Schema{type: :string}
      }
    })
  end

  defmodule ListRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ListRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        icon: %Schema{type: :string, nullable: true},
        color: %Schema{type: :string, nullable: true},
        position: %Schema{type: :integer}
      }
    })
  end

  defmodule TaskRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "TaskRequest",
      type: :object,
      properties: %{
        list_id: %Schema{type: :string, format: :uuid},
        title: %Schema{type: :string},
        notes: %Schema{type: :string, nullable: true},
        due_date: %Schema{type: :string, format: :date, nullable: true},
        position: %Schema{type: :integer}
      }
    })
  end

  defmodule GoalRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GoalRequest",
      type: :object,
      properties: %{
        title: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        reason: %Schema{type: :string, nullable: true}
      }
    })
  end

  defmodule GoalLinkTaskRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GoalLinkTaskRequest",
      type: :object,
      required: [:task_id],
      properties: %{
        task_id: %Schema{type: :string, format: :uuid}
      }
    })
  end

  defmodule NoteFolderRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NoteFolderRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        position: %Schema{type: :integer}
      }
    })
  end

  defmodule NoteRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NoteRequest",
      type: :object,
      properties: %{
        folder_id: %Schema{type: :string, format: :uuid},
        title: %Schema{type: :string},
        body: %Schema{type: :string, nullable: true},
        pinned: %Schema{type: :boolean},
        position: %Schema{type: :integer}
      }
    })
  end
end
