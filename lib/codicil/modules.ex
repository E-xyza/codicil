defmodule Codicil.Modules do
  @moduledoc """
  Context module for managing module records and dependencies in the database.
  """

  alias Codicil.Db.Module
  alias Codicil.Db.ModuleDependency
  alias Codicil.Db.Repo

  @doc """
  Creates a new module record.
  """
  def create(attrs) do
    %Module{}
    |> Module.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves a module by ID.
  Returns the module struct or nil if not found.
  """
  def get(id) when is_atom(id) do
    Repo.get(Module, to_string(id))
  end

  def get(id) when is_binary(id) do
    Repo.get(Module, id)
  end

  @doc """
  Updates a module record.
  """
  def update(%Module{} = module, attrs) do
    module
    |> Module.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a module record.
  """
  def delete(%Module{} = module) do
    Repo.delete(module)
  end

  @doc """
  Creates a new module dependency record.
  """
  def create_dependency(attrs) do
    %ModuleDependency{}
    |> ModuleDependency.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves a module dependency by ID.
  Returns the dependency struct or nil if not found.
  """
  def get_dependency(id) do
    Repo.get(ModuleDependency, id)
  end

  @doc """
  Deletes a module dependency record.
  """
  def delete_dependency(%ModuleDependency{} = module_dependency) do
    Repo.delete(module_dependency)
  end
end
