defmodule Codicil.Db.ModuleDependency do
  @moduledoc """
  Schema for module dependency relationships.

  Tracks two types of dependencies:
  - :compiler - Compile-time dependencies (import/require/use)
  - :runtime - Runtime dependencies (function calls between modules)
  """

  use Ecto.Schema
  import EctoEnum
  alias Ecto.Changeset

  defenum(DependencyType, compiler: 0, runtime: 1)

  schema "module_dependencies" do
    belongs_to :dependent, Codicil.Db.Mod, type: :string, foreign_key: :dependent_id
    belongs_to :dependency, Codicil.Db.Mod, type: :string, foreign_key: :dependency_id
    field :type, DependencyType
  end

  def changeset(module_dependency, attrs) do
    module_dependency
    |> Changeset.cast(attrs, [:dependent_id, :dependency_id, :type])
    |> Changeset.validate_required([:dependent_id, :dependency_id, :type])
  end
end
