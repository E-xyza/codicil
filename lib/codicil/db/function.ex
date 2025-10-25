defmodule Codicil.Db.Function do
  @moduledoc """
  Schema for storing function metadata and embeddings.

  Functions are indexed from Elixir source files and include:
  - Basic metadata (name, path, line numbers)
  - AI-generated summary
  - Vector embedding for semantic search
  - Checksum for change detection
  """

  use Ecto.Schema

  alias Ecto.Changeset

  schema "functions" do
    field(:name, :string)
    field(:arity, :integer)
    field(:exported, :boolean)
    field(:path, :string)
    field(:line, :integer)
    field(:parsed, :utc_datetime_usec)
    field(:docs, :string)
    field(:code, :string)
    field(:summary, :string)
    field(:embedding, :binary)
    field(:checksum, :string)
    field(:marked_for_deletion, :boolean, default: false)

    belongs_to(:module_info, Codicil.Db.Module, type: :string, foreign_key: :module)

    many_to_many(:calls, __MODULE__,
      join_through: "function_calls",
      join_keys: [caller_id: :id, callee_id: :id]
    )

    many_to_many(:called_by, __MODULE__,
      join_through: "function_calls",
      join_keys: [callee_id: :id, caller_id: :id]
    )
  end

  @doc """
  Changeset for creating and updating function records.
  Normalizes atom values for :name and :module fields to strings.
  Sets :parsed timestamp to current time if not provided.
  """
  def changeset(function \\ %__MODULE__{}, attrs) do
    attrs = normalize_attrs(attrs)

    function
    |> Changeset.cast(attrs, [
      :name,
      :module,
      :arity,
      :exported,
      :path,
      :line,
      :parsed,
      :docs,
      :code,
      :summary,
      :embedding,
      :checksum,
      :marked_for_deletion
    ])
    |> Changeset.validate_required([:name, :module, :arity])
    |> Changeset.put_change(:marked_for_deletion, false)
  end

  @doc """
  Changeset for marking a function for deletion.
  Preserves all other fields including checksum.
  """
  def mark_for_deletion_changeset(function) do
    function
    |> Changeset.change(%{marked_for_deletion: true})
  end

  @doc """
  Changeset for creating new function records.
  Requires all fields needed for a fully-defined function.
  """
  def create_changeset(function \\ %__MODULE__{}, attrs) do
    function
    |> changeset(attrs)
    |> Changeset.validate_required([:exported, :path, :line, :checksum])
    |> Changeset.put_change(:parsed, DateTime.utc_now())
  end

  defp normalize_attrs(attrs) do
    attrs
    |> normalize_atom_field(:name)
    |> normalize_atom_field(:module)
  end

  defp normalize_atom_field(attrs, key) do
    case Map.get(attrs, key) do
      value when is_atom(value) and not is_nil(value) ->
        Map.put(attrs, key, Atom.to_string(value))

      _ ->
        attrs
    end
  end
end
