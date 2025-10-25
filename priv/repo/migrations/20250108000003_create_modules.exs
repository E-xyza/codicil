defmodule Codicil.Db.Repo.Migrations.CreateModules do
  use Ecto.Migration

  def change do
    create table(:modules, primary_key: false) do
      add :id, :string, primary_key: true
      add :path, :string, null: false
      add :checksum, :string
      add :parsed, :utc_datetime_usec
      add :doc, :text
      add :summary, :text
      add :vector, :binary
      add :line, :integer
      add :marked_for_deletion, :boolean, default: false, null: false
    end

    create index(:modules, [:path])
  end
end
