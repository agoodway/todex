defmodule Todex.NotesTest do
  use Todex.DataCase, async: true

  alias Todex.Onboarding
  alias Todex.Notes

  defp user_fixture(email) do
    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    user
  end

  defp folder_fixture(user, attrs) do
    attrs = Map.merge(%{name: "Ideas", position: 10}, attrs)
    assert {:ok, folder} = Notes.create_folder(user, attrs)
    folder
  end

  defp note_fixture(user, folder, attrs) do
    attrs = Map.merge(%{title: "Note", body: "Body", folder_id: folder.id}, attrs)
    assert {:ok, note} = Notes.create_note(user, attrs)
    note
  end

  test "folder CRUD is scoped to the owning user and rejects active notes on delete" do
    user = user_fixture("notes-folders@example.com")
    other_user = user_fixture("notes-folders-other@example.com")

    assert [%{name: "Notes", is_default: true, position: 0}] = Notes.list_folders(user)

    folder = folder_fixture(user, %{"name" => "Projects", "is_default" => true})
    assert folder.user_id == user.id
    refute folder.is_default

    assert {:ok, updated} = Notes.update_folder(user, folder.id, %{"name" => "Archive"})
    assert updated.name == "Archive"

    assert nil == Notes.get_folder(other_user, folder.id)
    assert {:error, :not_found} = Notes.update_folder(other_user, folder.id, %{name: "Nope"})

    _note = note_fixture(user, folder, %{title: "Keep folder"})
    assert {:error, :folder_has_notes} = Notes.delete_folder(user, folder.id)
  end

  test "folder deletion succeeds after contained notes are soft deleted" do
    user = user_fixture("notes-folders-soft-delete@example.com")
    folder = folder_fixture(user, %{name: "Drafts"})
    note = note_fixture(user, folder, %{title: "Old draft"})

    assert {:ok, _note} = Notes.soft_delete_note(user, note.id)
    assert {:ok, deleted_folder} = Notes.delete_folder(user, folder.id)

    assert deleted_folder.id == folder.id
    assert nil == Notes.get_folder(user, folder.id)
    assert nil == Notes.get_note(user, note.id)
  end

  test "notes support filters, ownership, pinning, soft deletion, restore, and permanent deletion" do
    user = user_fixture("notes@example.com")
    other_user = user_fixture("notes-other@example.com")
    folder = folder_fixture(user, %{name: "Writing"})
    other_folder = folder_fixture(other_user, %{name: "Other writing"})

    assert {:error, :folder_not_found} =
             Notes.create_note(user, %{title: "Foreign", folder_id: other_folder.id})

    pinned = note_fixture(user, folder, %{title: "Pinned", body: "Alpha", pinned: true})
    normal = note_fixture(user, folder, %{title: "Normal", body: "Beta"})

    assert Enum.map(Notes.list_notes(user), & &1.id) == [pinned.id, normal.id]

    assert Enum.map(Notes.list_notes(user, %{folder_id: folder.id}), & &1.id) == [
             pinned.id,
             normal.id
           ]

    assert Enum.map(Notes.list_notes(user, %{q: "alpha"}), & &1.id) == [pinned.id]
    assert Enum.map(Notes.list_notes(user, %{pinned: "false"}), & &1.id) == [normal.id]
    assert [] == Notes.list_notes(user, %{folder_id: "not-a-uuid"})

    assert nil == Notes.get_note(other_user, pinned.id)
    assert {:error, :not_found} = Notes.update_note(other_user, pinned.id, %{title: "Nope"})

    assert {:error, :folder_not_found} =
             Notes.update_note(user, pinned.id, %{folder_id: other_folder.id})

    assert {:ok, unpinned} = Notes.unpin_note(user, pinned.id)
    refute unpinned.pinned
    assert {:ok, pinned_again} = Notes.pin_note(user, pinned.id)
    assert pinned_again.pinned

    assert {:ok, deleted} = Notes.soft_delete_note(user, normal.id)
    assert %DateTime{} = deleted.deleted_at
    assert Enum.map(Notes.list_notes(user), & &1.id) == [pinned.id]
    assert Enum.map(Notes.list_notes(user, %{deleted: "true"}), & &1.id) == [normal.id]

    assert {:ok, restored} = Notes.restore_note(user, normal.id)
    assert is_nil(restored.deleted_at)

    assert {:ok, permanently_deleted} = Notes.permanently_delete_note(user, normal.id)
    assert permanently_deleted.id == normal.id
    assert nil == Notes.get_note(user, normal.id)
  end
end
