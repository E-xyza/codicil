defmodule Codicil.Db.Module do
  @moduledoc """
  Schema for storing module metadata.

  Modules represent Elixir modules in the indexed codebase.
  """

  use Ecto.Schema
  alias Ecto.Changeset

  # The id field contains the module name (e.g., "MyApp.MyModule")
  @primary_key {:id, :string, autogenerate: false}
  schema "modules" do
    field(:path, :string)
    field(:checksum, :string)
    field(:parsed_at, :utc_datetime_usec)
    field(:doc, :string)
    field(:summary, :string)
    field(:vector, :binary)
    field(:line, :integer)
    field(:marked_for_deletion, :boolean, default: false)

    has_many(:functions, Codicil.Db.Function, foreign_key: :module)
  end

  def changeset(module, attrs) do
    # Convert atom module id to string if needed
    attrs =
      case attrs do
        %{id: id} when is_atom(id) -> %{attrs | id: "#{id}"}
        _ -> attrs
      end

    module
    |> Changeset.cast(attrs, [
      :id,
      :path,
      :checksum,
      :parsed_at,
      :doc,
      :summary,
      :vector,
      :line,
      :marked_for_deletion
    ])
    |> Changeset.validate_required([:id, :path])
    |> Changeset.put_change(:marked_for_deletion, false)
    |> maybe_set_parsed()
  end

  def mark_for_deletion_changeset(module) do
    module
    |> Changeset.change(%{marked_for_deletion: true})
  end

  defp maybe_set_parsed(changeset) do
    if Changeset.get_field(changeset, :parsed_at) do
      changeset
    else
      Changeset.put_change(changeset, :parsed_at, DateTime.utc_now())
    end
  end
end
