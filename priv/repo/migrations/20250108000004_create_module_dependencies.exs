defmodule Codicil.Db.Repo.Migrations.CreateModuleDependencies do
  use Ecto.Migration

  def change do
    create table(:module_dependencies) do
      add :dependent_id, references(:mods, type: :string, on_delete: :delete_all), null: false
      add :dependency_id, references(:mods, type: :string, on_delete: :delete_all), null: false
      add :type, :integer, null: false
    end

    create unique_index(:module_dependencies, [:dependent_id, :dependency_id, :type])
    create index(:module_dependencies, [:dependent_id])
    create index(:module_dependencies, [:dependency_id])
    create index(:module_dependencies, [:type])
  end
end
