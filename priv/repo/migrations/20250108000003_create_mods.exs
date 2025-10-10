defmodule Codicil.Db.Repo.Migrations.CreateMods do
  use Ecto.Migration

  def change do
    create table(:mods, primary_key: false) do
      add :id, :string, primary_key: true
      add :path, :string, null: false
      add :checksum, :string, null: false
      add :parsed, :utc_datetime_usec
      add :doc, :text
      add :summary, :text
      add :vector, :binary
      add :line, :integer
    end

    create unique_index(:mods, [:path])
  end
end
