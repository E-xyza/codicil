defmodule Codicil.Db.Repo.Migrations.CreateFunctions do
  use Ecto.Migration

  def change do
    create table(:functions) do
      add :name, :string, null: false
      add :module, :string, null: false
      add :arity, :integer, null: false
      add :path, :string, null: false
      add :start_line, :integer, null: false
      add :end_line, :integer, null: false
      add :parsed, :utc_datetime_usec
      add :summary, :text
      add :embedding, :binary
      add :checksum, :string, null: false
    end

    create unique_index(:functions, [:module, :name, :arity, :path])
  end
end
