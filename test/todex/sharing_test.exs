defmodule Todex.SharingTest do
  use Todex.DataCase, async: true

  alias Todex.Notes
  alias Todex.Onboarding
  alias Todex.Sharing
  alias Todex.Todos

  defp user_fixture(prefix) do
    email = "#{prefix}-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{user: user}} =
             Onboarding.register_user(%{email: email, password: "super-secret-password"})

    user
  end

  defp list_fixture(user, attrs \\ %{}) do
    attrs = Map.merge(%{name: "Shared List", position: 20}, attrs)
    assert {:ok, list} = Todos.create_list(user, attrs)
    list
  end

  defp note_fixture(user, attrs \\ %{}) do
    [folder | _] = Notes.list_folders(user)
    attrs = Map.merge(%{folder_id: folder.id, title: "Shared Note", body: "Body"}, attrs)
    assert {:ok, note} = Notes.create_note(user, attrs)
    note
  end

  test "find_recipient_by_email normalizes email before lookup" do
    recipient = user_fixture("sharing-recipient")

    assert %{id: id} = Sharing.find_recipient_by_email("  #{String.upcase(recipient.email)}  ")
    assert id == recipient.id
    assert nil == Sharing.find_recipient_by_email("missing@example.com")
  end

  test "list share lifecycle supports create, list, update, delete, and shared listing" do
    owner = user_fixture("list-share-domain-owner")
    recipient = user_fixture("list-share-domain-recipient")
    list = list_fixture(owner)

    assert {:ok, share} =
             Sharing.create_list_share(owner, list.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert share.owner_id == owner.id
    assert share.recipient_id == recipient.id
    assert share.list_id == list.id
    assert share.role == :viewer

    assert {:ok, [listed]} = Sharing.list_list_shares(owner, list.id)
    assert listed.id == share.id

    assert {:ok, %{items: [%{share: shared_share, list: shared_list}], total: 1}} =
             Sharing.list_shared_lists(recipient)

    assert shared_share.id == share.id
    assert shared_list.id == list.id

    assert {:ok, updated} = Sharing.update_list_share(owner, list.id, share.id, %{role: "editor"})
    assert updated.role == :editor
    assert Sharing.list_permission(recipient, list.id) == :editor
    assert Sharing.list_permission(owner, list.id) == :owner
    assert Sharing.can_view_list?(recipient, list.id)
    assert Sharing.can_edit_list?(recipient, list.id)

    assert {:ok, deleted} = Sharing.delete_list_share(owner, list.id, share.id)
    assert deleted.id == share.id
    assert {:ok, []} = Sharing.list_list_shares(owner, list.id)
    assert {:ok, %{items: [], total: 0}} = Sharing.list_shared_lists(recipient)
    assert nil == Sharing.list_permission(recipient, list.id)
  end

  test "note share lifecycle supports create, list, update, delete, and shared listing" do
    owner = user_fixture("note-share-domain-owner")
    recipient = user_fixture("note-share-domain-recipient")
    note = note_fixture(owner)

    assert {:ok, share} =
             Sharing.create_note_share(owner, note.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert share.owner_id == owner.id
    assert share.recipient_id == recipient.id
    assert share.note_id == note.id
    assert share.role == :viewer

    assert {:ok, [listed]} = Sharing.list_note_shares(owner, note.id)
    assert listed.id == share.id

    assert {:ok, %{items: [%{share: shared_share, note: shared_note}], total: 1}} =
             Sharing.list_shared_notes(recipient)

    assert shared_share.id == share.id
    assert shared_note.id == note.id

    assert {:ok, updated} = Sharing.update_note_share(owner, note.id, share.id, %{role: "editor"})
    assert updated.role == :editor
    assert Sharing.note_permission(recipient, note.id) == :editor
    assert Sharing.note_permission(owner, note.id) == :owner
    assert Sharing.can_view_note?(recipient, note.id)
    assert Sharing.can_edit_note?(recipient, note.id)

    assert {:ok, deleted} = Sharing.delete_note_share(owner, note.id, share.id)
    assert deleted.id == share.id
    assert {:ok, []} = Sharing.list_note_shares(owner, note.id)
    assert {:ok, %{items: [], total: 0}} = Sharing.list_shared_notes(recipient)
    assert nil == Sharing.note_permission(recipient, note.id)
  end

  test "shared notes listing excludes soft-deleted notes" do
    owner = user_fixture("soft-deleted-shared-note-owner")
    recipient = user_fixture("soft-deleted-shared-note-recipient")
    note = note_fixture(owner)

    assert {:ok, _share} =
             Sharing.create_note_share(owner, note.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert {:ok, %{items: [%{note: shared_note}], total: 1}} =
             Sharing.list_shared_notes(recipient)

    assert shared_note.id == note.id

    assert {:ok, _deleted_note} = Notes.soft_delete_note(owner, note.id)
    assert {:ok, %{items: [], total: 0}} = Sharing.list_shared_notes(recipient)
  end

  test "recipients cannot read or edit a soft-deleted shared note while the owner retains access" do
    owner = user_fixture("soft-deleted-access-owner")
    recipient = user_fixture("soft-deleted-access-recipient")
    note = note_fixture(owner)

    assert {:ok, _share} =
             Sharing.create_note_share(owner, note.id, %{
               recipient_email: recipient.email,
               role: "editor"
             })

    assert %{id: note_id} = Notes.get_note(recipient, note.id)
    assert note_id == note.id

    assert {:ok, _deleted} = Notes.soft_delete_note(owner, note.id)

    assert nil == Notes.get_note(recipient, note.id)

    assert {:error, :not_found} =
             Notes.update_note(recipient, note.id, %{title: "hijacked"})

    # Owner can still read, restore, and permanently delete the soft-deleted note.
    assert %{id: ^note_id} = Notes.get_note(owner, note.id)
    assert {:ok, _restored} = Notes.restore_note(owner, note.id)
    assert %{id: ^note_id} = Notes.get_note(recipient, note.id)
  end

  test "note share validation rejects roles outside the note share role set" do
    owner = user_fixture("note-role-validation-owner")
    recipient = user_fixture("note-role-validation-recipient")
    note = note_fixture(owner)

    assert {:error, changeset} =
             Sharing.create_note_share(owner, note.id, %{
               recipient_email: recipient.email,
               role: "admin"
             })

    assert %{role: ["is invalid"]} = errors_on(changeset)

    assert {:ok, share} =
             Sharing.create_note_share(owner, note.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert {:error, update_changeset} =
             Sharing.update_note_share(owner, note.id, share.id, %{role: "admin"})

    assert %{role: ["is invalid"]} = errors_on(update_changeset)
  end

  test "shared list listing paginates at the database level while reporting the full total" do
    owner = user_fixture("shared-pagination-owner")
    recipient = user_fixture("shared-pagination-recipient")

    lists =
      for index <- 1..3 do
        list = list_fixture(owner, %{name: "List #{index}", position: index})

        assert {:ok, _share} =
                 Sharing.create_list_share(owner, list.id, %{
                   recipient_email: recipient.email,
                   role: "viewer"
                 })

        list
      end

    assert {:ok, %{items: page_one, total: 3}} =
             Sharing.list_shared_lists(recipient, page: 1, page_size: 2)

    assert {:ok, %{items: page_two, total: 3}} =
             Sharing.list_shared_lists(recipient, page: 2, page_size: 2)

    assert length(page_one) == 2
    assert length(page_two) == 1

    returned_ids = Enum.map(page_one ++ page_two, & &1.list.id)
    assert Enum.sort(returned_ids) == Enum.sort(Enum.map(lists, & &1.id))
  end

  test "recipient id helpers return owner plus recipients and tolerate missing or invalid ids" do
    owner = user_fixture("recipient-ids-owner")
    recipient = user_fixture("recipient-ids-recipient")
    list = list_fixture(owner)
    note = note_fixture(owner)

    assert Sharing.list_recipient_ids(list.id) == [owner.id]
    assert Sharing.note_recipient_ids(note.id) == [owner.id]

    assert {:ok, _} =
             Sharing.create_list_share(owner, list.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert {:ok, _} =
             Sharing.create_note_share(owner, note.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert Enum.sort(Sharing.list_recipient_ids(list.id)) == Enum.sort([owner.id, recipient.id])
    assert Enum.sort(Sharing.note_recipient_ids(note.id)) == Enum.sort([owner.id, recipient.id])

    assert Sharing.list_recipient_ids(Ecto.UUID.generate()) == []
    assert Sharing.note_recipient_ids(Ecto.UUID.generate()) == []
    assert Sharing.list_recipient_ids("not-a-uuid") == []
    assert Sharing.note_recipient_ids("not-a-uuid") == []
  end

  test "share creation returns neutral success for unknown recipients without creating a share" do
    owner = user_fixture("neutral-share-owner")
    list = list_fixture(owner)
    note = note_fixture(owner)

    assert {:ok, nil} =
             Sharing.create_list_share(owner, list.id, %{
               recipient_email: "unknown@example.com",
               role: "viewer"
             })

    assert {:ok, nil} =
             Sharing.create_note_share(owner, note.id, %{
               recipient_email: "unknown@example.com",
               role: "viewer"
             })

    assert {:ok, []} = Sharing.list_list_shares(owner, list.id)
    assert {:ok, []} = Sharing.list_note_shares(owner, note.id)
  end

  test "share management hides resources from non-owners" do
    owner = user_fixture("share-owner-only-owner")
    recipient = user_fixture("share-owner-only-recipient")
    stranger = user_fixture("share-owner-only-stranger")
    list = list_fixture(owner)
    note = note_fixture(owner)

    assert {:ok, list_share} =
             Sharing.create_list_share(owner, list.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert {:ok, note_share} =
             Sharing.create_note_share(owner, note.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert {:error, :not_found} = Sharing.list_list_shares(recipient, list.id)

    assert {:error, :not_found} =
             Sharing.update_list_share(recipient, list.id, list_share.id, %{role: "editor"})

    assert {:error, :not_found} = Sharing.delete_list_share(recipient, list.id, list_share.id)
    assert {:error, :not_found} = Sharing.list_list_shares(stranger, list.id)

    assert {:error, :not_found} = Sharing.list_note_shares(recipient, note.id)

    assert {:error, :not_found} =
             Sharing.update_note_share(recipient, note.id, note_share.id, %{role: "editor"})

    assert {:error, :not_found} = Sharing.delete_note_share(recipient, note.id, note_share.id)
    assert {:error, :not_found} = Sharing.list_note_shares(stranger, note.id)
  end

  test "share creation rejects self shares, duplicate shares, and malformed email" do
    owner = user_fixture("share-validation-owner")
    recipient = user_fixture("share-validation-recipient")
    list = list_fixture(owner)

    assert {:error, :cannot_share_with_self} =
             Sharing.create_list_share(owner, list.id, %{
               recipient_email: owner.email,
               role: "viewer"
             })

    assert {:error, changeset} =
             Sharing.create_list_share(owner, list.id, %{
               recipient_email: "not-an-email",
               role: "viewer"
             })

    assert %{recipient_email: ["has invalid format"]} = errors_on(changeset)

    assert {:ok, _share} =
             Sharing.create_list_share(owner, list.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })

    assert {:error, :share_already_exists} =
             Sharing.create_list_share(owner, list.id, %{
               recipient_email: recipient.email,
               role: "viewer"
             })
  end
end
