defmodule Codicil.Db.Repo.Migrations.CreateFunctions do
  use Ecto.Migration

  def change do
    create table(:functions) do
      add :name, :string, null: false
      add :module, :string, null: false
      add :arity, :integer, null: false
      add :exported, :boolean, null: false, default: true
      add :path, :string, null: false
      add :line, :integer, null: false
      add :parsed, :utc_datetime_usec
      add :docs, :text
      add :summary, :text
      add :embedding, :binary
      add :checksum, :string, null: false
    end

    create unique_index(:functions, [:module, :name, :arity, :path])
  end
end
