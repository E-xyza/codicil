defmodule Codicil.ModuleDependency do
  @moduledoc """
  Context module for managing module dependency records in the database.
  """

  alias Codicil.Db.ModuleDependency
  alias Codicil.Db.Repo

  @doc """
  Creates a new module dependency record.
  """
  def create(attrs) do
    %ModuleDependency{}
    |> ModuleDependency.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves a module dependency by ID.
  Returns the dependency struct or nil if not found.
  """
  def get(id) do
    Repo.get(ModuleDependency, id)
  end

  @doc """
  Deletes a module dependency record.
  """
  def delete(%ModuleDependency{} = module_dependency) do
    Repo.delete(module_dependency)
  end
end
