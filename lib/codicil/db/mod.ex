defmodule Codicil.Db.Mod do
  @moduledoc """
  Schema for storing module metadata.

  Modules represent Elixir modules in the indexed codebase.
  """

  use Ecto.Schema
  alias Ecto.Changeset

  # The id field contains the module name (e.g., "MyApp.MyModule")
  @primary_key {:id, :string, autogenerate: false}
  schema "mods" do
    field(:path, :string)
    field(:checksum, :string)
    field(:parsed, :utc_datetime_usec)
    field(:doc, :string)
    field(:summary, :string)
    field(:vector, :binary)
    field(:line, :integer)

    has_many(:functions, Codicil.Db.Function, foreign_key: :module)
  end

  def changeset(mod, attrs) do
    # Convert atom module id to string if needed
    attrs = case attrs do
      %{id: id} when is_atom(id) -> %{attrs | id: "#{id}"}
      _ -> attrs
    end

    mod
    |> Changeset.cast(attrs, [:id, :path, :checksum, :parsed, :doc, :summary, :vector, :line])
    |> Changeset.validate_required([:id, :path, :checksum])
    |> maybe_set_parsed()
  end

  defp maybe_set_parsed(changeset) do
    if Changeset.get_field(changeset, :parsed) do
      changeset
    else
      Changeset.put_change(changeset, :parsed, DateTime.utc_now())
    end
  end
end
