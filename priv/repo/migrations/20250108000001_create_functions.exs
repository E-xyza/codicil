defmodule Codicil.Db.Repo.Migrations.CreateFunctions do
  use Ecto.Migration

  def change do
    create table(:functions) do
      add :name, :string, null: false
      add :module, :string, null: false
      add :arity, :integer, null: false
      add :exported, :boolean
      add :path, :string
      add :line, :integer
      add :parsed_at, :utc_datetime_usec
      add :docs, :text
      add :code, :text
      add :summary, :text
      add :embedding, :binary
      add :checksum, :string
      add :marked_for_deletion, :boolean, default: false, null: false
    end

    create unique_index(:functions, [:module, :name, :arity])
  end
end
