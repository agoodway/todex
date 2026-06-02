defmodule Todex.SchemaTest do
  use Todex.DataCase, async: true

  alias Todex.Accounts.User
  alias Todex.Goals.Goal
  alias Todex.Goals.GoalTask
  alias Todex.Notes
  alias Todex.Notes.Note
  alias Todex.Notes.NoteFolder
  alias Todex.Onboarding
  alias Todex.Sharing.ListShare
  alias Todex.Sharing.NoteShare
  alias Todex.Todos
  alias Todex.Todos.List
  alias Todex.Todos.Task

  test "user registration changeset requires email and password" do
    changeset = User.registration_changeset(%User{}, %{})

    assert %{email: ["can't be blank"], password: ["can't be blank"]} = errors_on(changeset)
  end

  test "list changeset requires user_id and name" do
    changeset = List.changeset(%List{}, %{})

    assert %{user_id: ["can't be blank"], name: ["can't be blank"]} = errors_on(changeset)
  end

  test "task changeset requires title, user_id, and list_id" do
    changeset = Task.changeset(%Task{}, %{})

    assert %{
             title: ["can't be blank"],
             user_id: ["can't be blank"],
             list_id: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "note folder changeset requires user_id and name" do
    changeset = NoteFolder.changeset(%NoteFolder{}, %{})

    assert %{user_id: ["can't be blank"], name: ["can't be blank"]} = errors_on(changeset)
  end

  test "note changeset requires title, user_id, and folder_id" do
    changeset = Note.changeset(%Note{}, %{})

    assert %{
             title: ["can't be blank"],
             user_id: ["can't be blank"],
             folder_id: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "goal changeset requires user_id and title" do
    changeset = Goal.changeset(%Goal{}, %{})

    assert %{user_id: ["can't be blank"], title: ["can't be blank"]} = errors_on(changeset)
  end

  test "goal changeset rejects title over 255 characters" do
    changeset =
      Goal.changeset(%Goal{}, %{
        user_id: Ecto.UUID.generate(),
        title: String.duplicate("x", 256)
      })

    assert %{title: [_ | _]} = errors_on(changeset)
  end

  test "goal changeset ignores client-supplied progress" do
    changeset =
      Goal.changeset(%Goal{}, %{
        user_id: Ecto.UUID.generate(),
        title: "Launch",
        description: "Ship the API",
        reason: "Users need it",
        progress: 75
      })

    refute Map.has_key?(changeset.changes, :progress)
  end

  test "goal task changeset requires user_id, goal_id, and task_id" do
    changeset = GoalTask.changeset(%GoalTask{}, %{})

    assert %{
             user_id: ["can't be blank"],
             goal_id: ["can't be blank"],
             task_id: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "list share changeset requires owner_id, recipient_id, list_id, and role" do
    changeset = ListShare.changeset(%ListShare{}, %{})

    assert %{
             owner_id: ["can't be blank"],
             recipient_id: ["can't be blank"],
             list_id: ["can't be blank"],
             role: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "note share changeset requires owner_id, recipient_id, note_id, and role" do
    changeset = NoteShare.changeset(%NoteShare{}, %{})

    assert %{
             owner_id: ["can't be blank"],
             recipient_id: ["can't be blank"],
             note_id: ["can't be blank"],
             role: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "share changesets accept only viewer and editor roles" do
    valid_attrs = %{
      owner_id: Ecto.UUID.generate(),
      recipient_id: Ecto.UUID.generate(),
      list_id: Ecto.UUID.generate(),
      role: "admin"
    }

    assert %{role: ["is invalid"]} = errors_on(ListShare.changeset(%ListShare{}, valid_attrs))

    note_attrs = valid_attrs |> Map.delete(:list_id) |> Map.put(:note_id, Ecto.UUID.generate())
    assert %{role: ["is invalid"]} = errors_on(NoteShare.changeset(%NoteShare{}, note_attrs))

    assert ListShare.changeset(%ListShare{}, %{valid_attrs | role: "viewer"}).valid?
    assert ListShare.changeset(%ListShare{}, %{valid_attrs | role: "editor"}).valid?
    assert NoteShare.changeset(%NoteShare{}, %{note_attrs | role: "viewer"}).valid?
    assert NoteShare.changeset(%NoteShare{}, %{note_attrs | role: "editor"}).valid?
  end

  test "share changesets reject sharing with self" do
    user_id = Ecto.UUID.generate()

    assert %{recipient_id: ["cannot share with self"]} =
             errors_on(
               ListShare.changeset(%ListShare{}, %{
                 owner_id: user_id,
                 recipient_id: user_id,
                 list_id: Ecto.UUID.generate(),
                 role: "viewer"
               })
             )

    assert %{recipient_id: ["cannot share with self"]} =
             errors_on(
               NoteShare.changeset(%NoteShare{}, %{
                 owner_id: user_id,
                 recipient_id: user_id,
                 note_id: Ecto.UUID.generate(),
                 role: "viewer"
               })
             )
  end

  test "duplicate list shares are rejected per list and recipient" do
    owner = register_schema_user("list-share-owner")
    recipient = register_schema_user("list-share-recipient")
    [list | _] = Todos.list_lists(owner)

    attrs = %{
      owner_id: owner.id,
      recipient_id: recipient.id,
      list_id: list.id,
      role: "viewer"
    }

    assert {:ok, _share} = %ListShare{} |> ListShare.changeset(attrs) |> Repo.insert()
    assert {:error, changeset} = %ListShare{} |> ListShare.changeset(attrs) |> Repo.insert()
    assert %{recipient_id: ["has already been taken"]} = errors_on(changeset)
  end

  test "list shares require the owner to own the shared list" do
    actual_owner = register_schema_user("list-share-actual-owner")
    wrong_owner = register_schema_user("list-share-wrong-owner")
    recipient = register_schema_user("list-share-owner-match-recipient")
    [list | _] = Todos.list_lists(actual_owner)

    attrs = %{
      owner_id: wrong_owner.id,
      recipient_id: recipient.id,
      list_id: list.id,
      role: "viewer"
    }

    assert {:error, changeset} = %ListShare{} |> ListShare.changeset(attrs) |> Repo.insert()
    assert %{list_id: ["does not exist"]} = errors_on(changeset)
  end

  test "duplicate note shares are rejected per note and recipient" do
    owner = register_schema_user("note-share-owner")
    recipient = register_schema_user("note-share-recipient")
    [folder | _] = Notes.list_folders(owner)
    assert {:ok, note} = Notes.create_note(owner, %{folder_id: folder.id, title: "Shared note"})

    attrs = %{
      owner_id: owner.id,
      recipient_id: recipient.id,
      note_id: note.id,
      role: "viewer"
    }

    assert {:ok, _share} = %NoteShare{} |> NoteShare.changeset(attrs) |> Repo.insert()
    assert {:error, changeset} = %NoteShare{} |> NoteShare.changeset(attrs) |> Repo.insert()
    assert %{recipient_id: ["has already been taken"]} = errors_on(changeset)
  end

  test "note shares require the owner to own the shared note" do
    actual_owner = register_schema_user("note-share-actual-owner")
    wrong_owner = register_schema_user("note-share-wrong-owner")
    recipient = register_schema_user("note-share-owner-match-recipient")
    [folder | _] = Notes.list_folders(actual_owner)

    assert {:ok, note} =
             Notes.create_note(actual_owner, %{folder_id: folder.id, title: "Owned note"})

    attrs = %{
      owner_id: wrong_owner.id,
      recipient_id: recipient.id,
      note_id: note.id,
      role: "viewer"
    }

    assert {:error, changeset} = %NoteShare{} |> NoteShare.changeset(attrs) |> Repo.insert()
    assert %{note_id: ["does not exist"]} = errors_on(changeset)
  end

  # ---------------------------------------------------------------------------
  # Schema validation: email format
  # ---------------------------------------------------------------------------

  test "register_user rejects invalid email format" do
    assert {:error, changeset} =
             Onboarding.register_user(%{email: "not-an-email", password: "super-secret"})

    assert %{email: ["has invalid format"]} = errors_on(changeset)
  end

  # ---------------------------------------------------------------------------
  # Schema validation: password length bounds
  # ---------------------------------------------------------------------------

  test "register_user rejects password shorter than 8 characters (7 chars fails)" do
    assert {:error, changeset} =
             Onboarding.register_user(%{
               email: "short-pw-7@example.com",
               password: String.duplicate("a", 7)
             })

    assert %{password: [_ | _]} = errors_on(changeset)
  end

  test "register_user accepts password of exactly 8 characters" do
    email = "short-pw-8-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, _} =
             Onboarding.register_user(%{email: email, password: String.duplicate("a", 8)})
  end

  test "register_user accepts password of exactly 72 characters" do
    email = "long-pw-72-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, _} =
             Onboarding.register_user(%{email: email, password: String.duplicate("a", 72)})
  end

  test "register_user rejects password longer than 72 characters (73 chars fails)" do
    assert {:error, changeset} =
             Onboarding.register_user(%{
               email: "long-pw@example.com",
               password: String.duplicate("a", 73)
             })

    assert %{password: [_ | _]} = errors_on(changeset)
  end

  # ---------------------------------------------------------------------------
  # Schema validation: list/folder name max length (80)
  # ---------------------------------------------------------------------------

  test "list changeset rejects name over 80 characters" do
    changeset =
      List.changeset(%List{}, %{user_id: Ecto.UUID.generate(), name: String.duplicate("x", 81)})

    assert %{name: [_ | _]} = errors_on(changeset)
  end

  test "note folder changeset rejects name over 80 characters" do
    changeset =
      NoteFolder.changeset(%NoteFolder{}, %{
        user_id: Ecto.UUID.generate(),
        name: String.duplicate("x", 81)
      })

    assert %{name: [_ | _]} = errors_on(changeset)
  end

  # ---------------------------------------------------------------------------
  # Schema validation: task/note title max length (255)
  # ---------------------------------------------------------------------------

  test "task changeset rejects title over 255 characters" do
    changeset =
      Task.changeset(%Task{}, %{
        user_id: Ecto.UUID.generate(),
        list_id: Ecto.UUID.generate(),
        title: String.duplicate("x", 256)
      })

    assert %{title: [_ | _]} = errors_on(changeset)
  end

  test "note changeset rejects title over 255 characters" do
    changeset =
      Note.changeset(%Note{}, %{
        user_id: Ecto.UUID.generate(),
        folder_id: Ecto.UUID.generate(),
        title: String.duplicate("x", 256)
      })

    assert %{title: [_ | _]} = errors_on(changeset)
  end

  # ---------------------------------------------------------------------------
  # Unique name on update: lists
  # ---------------------------------------------------------------------------

  test "updating a list to the name of an existing list for the same user returns changeset error on :name" do
    email = "schema-unique-list-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    assert {:ok, list_a} = Todos.create_list(user, %{name: "Alpha", position: 10})
    assert {:ok, list_b} = Todos.create_list(user, %{name: "Beta", position: 11})

    assert {:error, changeset} = Todos.update_list(user, list_b.id, %{name: list_a.name})
    assert %{name: ["has already been taken"]} = errors_on(changeset)
  end

  test "creating two lists with the same name for the same user returns changeset error on :name" do
    email = "schema-unique-list-create-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    assert {:ok, _list} = Todos.create_list(user, %{name: "Duplicate", position: 10})
    assert {:error, changeset} = Todos.create_list(user, %{name: "Duplicate", position: 11})
    assert %{name: ["has already been taken"]} = errors_on(changeset)
  end

  # ---------------------------------------------------------------------------
  # Unique name on update: note folders
  # ---------------------------------------------------------------------------

  test "updating a note folder to the name of an existing folder for the same user returns changeset error on :name" do
    email = "schema-unique-folder-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    assert {:ok, folder_a} = Notes.create_folder(user, %{name: "Folder Alpha", position: 10})
    assert {:ok, folder_b} = Notes.create_folder(user, %{name: "Folder Beta", position: 11})

    assert {:error, changeset} = Notes.update_folder(user, folder_b.id, %{name: folder_a.name})
    assert %{name: ["has already been taken"]} = errors_on(changeset)
  end

  test "creating two note folders with the same name for the same user returns changeset error on :name" do
    email = "schema-unique-folder-create-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    assert {:ok, _folder} = Notes.create_folder(user, %{name: "Duplicate Folder", position: 10})

    assert {:error, changeset} =
             Notes.create_folder(user, %{name: "Duplicate Folder", position: 11})

    assert %{name: ["has already been taken"]} = errors_on(changeset)
  end

  defp register_schema_user(prefix) do
    email = "#{prefix}-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    user
  end
end
