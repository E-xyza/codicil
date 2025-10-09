defmodule Codicil.Db.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    create table(:files) do
      add :path, :string, null: false
      add :checksum, :string, null: false
      add :parsed, :utc_datetime_usec
    end

    create unique_index(:files, [:path])
  end
end
