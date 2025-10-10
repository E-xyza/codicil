defmodule Codicil.Mod do
  @moduledoc """
  Context module for managing module records in the database.
  """

  alias Codicil.Db.Mod
  alias Codicil.Db.Repo

  @doc """
  Creates a new module record.
  """
  def create(attrs) do
    %Mod{}
    |> Mod.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves a module by ID.
  Returns the module struct or nil if not found.
  """
  def get(id) when is_atom(id) do
    Repo.get(Mod, to_string(id))
  end

  def get(id) when is_binary(id) do
    Repo.get(Mod, id)
  end

  @doc """
  Updates a module record.
  """
  def update(%Mod{} = mod, attrs) do
    mod
    |> Mod.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a module record.
  """
  def delete(%Mod{} = mod) do
    Repo.delete(mod)
  end
end
