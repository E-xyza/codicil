defmodule Codicil.Modules do
  @moduledoc """
  Context module for managing module records in the database.
  """

  alias Codicil.Db.Module
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
end
