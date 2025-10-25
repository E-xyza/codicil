defmodule Codicil.Modules do
  # Context module for managing module records and dependencies in the database.
  @moduledoc false

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
  Creates or updates a module record (upsert by module id).
  """
  def upsert(attrs) do
    %Module{}
    |> Module.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: :id
    )
  end

  @doc """
  Lists all modules.
  Returns a list of module structs.
  """
  def list do
    Repo.all(Module)
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
  Deletes all dependencies for a given module (as the dependent).
  """
  def delete_all_dependencies(module_id) when is_atom(module_id) do
    delete_all_dependencies(Atom.to_string(module_id))
  end

  def delete_all_dependencies(module_id) when is_binary(module_id) do
    import Ecto.Query

    from(md in ModuleDependency, where: md.dependent_id == ^module_id)
    |> Repo.delete_all()
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

  @doc """
  Lists all compile-time dependencies for the given module.
  """
  def list_compile_dependencies(%Module{id: id}) do
    import Ecto.Query

    from(m in Module,
      join: md in ModuleDependency,
      on: md.dependency_id == m.id,
      where: md.dependent_id == ^id and md.type == :compiler,
      select: m
    )
    |> Repo.all()
  end

  @doc """
  Lists all runtime dependencies for the given module.
  """
  def list_runtime_dependencies(%Module{id: id}) do
    import Ecto.Query

    from(m in Module,
      join: md in ModuleDependency,
      on: md.dependency_id == m.id,
      where: md.dependent_id == ^id and md.type == :runtime,
      select: m
    )
    |> Repo.all()
  end

  @doc """
  Lists all modules associated with a given file path.
  Returns a list of Module structs.
  """
  def list_by_path(path) when is_binary(path) do
    import Ecto.Query

    from(m in Module,
      where: m.path == ^path
    )
    |> Repo.all()
  end

  @doc """
  Marks a module for deletion.
  Preserves all data including checksum for potential reuse on rename.
  """
  def mark_for_deletion(%Module{} = module) do
    module
    |> Module.mark_for_deletion_changeset()
    |> Repo.update()
  end

  @doc """
  Garbage collects all modules marked for deletion.
  Called on application startup to clean up stale data.
  Returns {count, nil} where count is the number of deleted modules.
  """
  def garbage_collect_marked do
    import Ecto.Query

    from(m in Module, where: m.marked_for_deletion == true)
    |> Repo.delete_all()
  end
end
