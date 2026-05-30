defmodule Todex.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Todex.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Todex.DataCase
    end
  end

  setup tags do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Todex.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)
    :ok
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
