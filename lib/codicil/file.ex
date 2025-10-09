defmodule Codicil.File do
  @moduledoc """
  Context module for managing file records in the database.
  """

  alias Codicil.Db.{File, Repo}
  alias Ecto.Changeset

  @doc """
  Creates a new file record.
  """
  def create(attrs) do
    %File{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves a file by ID.
  Returns the file struct or nil if not found.
  """
  def get(id) do
    Repo.get(File, id)
  end

  @doc """
  Updates a file record.
  """
  def update(%File{} = file, attrs) do
    file
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a file record.
  """
  def delete(%File{} = file) do
    Repo.delete(file)
  end

  defp changeset(%File{} = file, attrs) do
    file
    |> Changeset.cast(attrs, [:path, :checksum, :parsed])
    |> Changeset.validate_required([:path, :checksum])
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
