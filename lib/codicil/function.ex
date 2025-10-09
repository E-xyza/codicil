defmodule Codicil.Function do
  @moduledoc """
  Context module for managing function records in the database.
  """

  alias Codicil.Db.{Function, Repo}
  alias Ecto.Changeset

  @doc """
  Creates a new function record.
  """
  def create(attrs) do
    %Function{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves a function by ID.
  Returns the function struct or nil if not found.
  """
  def get(id) do
    Repo.get(Function, id)
  end

  @doc """
  Updates a function record.
  """
  def update(%Function{} = function, attrs) do
    function
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a function record.
  """
  def delete(%Function{} = function) do
    Repo.delete(function)
  end

  defp changeset(%Function{} = function, attrs) do
    function
    |> Changeset.cast(attrs, [
      :name,
      :module,
      :arity,
      :path,
      :start_line,
      :end_line,
      :parsed,
      :summary,
      :embedding,
      :checksum
    ])
    |> Changeset.validate_required([:name, :module, :arity, :path, :start_line, :end_line, :checksum])
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
