defmodule Codicil.Edge do
  @moduledoc """
  Context module for managing edge records in the database.

  Edges represent relationships between functions such as calls and imports.
  """

  alias Codicil.Db.{Edge, Repo}
  alias Ecto.Changeset

  @doc """
  Creates a new edge record.
  """
  def create(attrs) do
    %Edge{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves an edge by ID.
  Returns the edge struct or nil if not found.
  """
  def get(id) do
    Repo.get(Edge, id)
  end

  @doc """
  Deletes an edge record.
  """
  def delete(%Edge{} = edge) do
    Repo.delete(edge)
  end

  defp changeset(%Edge{} = edge, attrs) do
    edge
    |> Changeset.cast(attrs, [:from_id, :to_id, :type])
    |> Changeset.validate_required([:from_id, :to_id, :type])
    |> Changeset.validate_inclusion(:type, ["calls", "imports_from"])
  end
end
