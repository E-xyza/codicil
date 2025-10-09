defmodule Codicil.Db.Repo.Migrations.CreateEdges do
  use Ecto.Migration

  def change do
    create table(:edges) do
      add :from_id, :integer, null: false
      add :to_id, :integer, null: false
      add :type, :string, null: false
    end

    create index(:edges, [:from_id])
    create index(:edges, [:to_id])
    create index(:edges, [:type])
  end
end
