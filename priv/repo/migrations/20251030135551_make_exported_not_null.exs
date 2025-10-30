defmodule Codicil.Db.Repo.Migrations.MakeExportedNotNull do
  use Ecto.Migration

  def up do
    # Fill in any existing NULL values with true as default
    execute "UPDATE functions SET exported = true WHERE exported IS NULL"

    # SQLite doesn't support ALTER COLUMN for constraints, so we need to recreate the table
    execute """
    CREATE TABLE functions_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      module TEXT NOT NULL,
      arity INTEGER NOT NULL,
      exported INTEGER NOT NULL,
      path TEXT,
      line INTEGER,
      parsed_at TEXT,
      docs TEXT,
      code TEXT,
      summary TEXT,
      embedding BLOB,
      checksum TEXT,
      marked_for_deletion INTEGER DEFAULT 0 NOT NULL
    )
    """

    execute """
    INSERT INTO functions_new
    SELECT id, name, module, arity, exported, path, line, parsed_at, docs, code, summary, embedding, checksum, marked_for_deletion
    FROM functions
    """

    execute "DROP TABLE functions"
    execute "ALTER TABLE functions_new RENAME TO functions"

    # Recreate the unique index
    create unique_index(:functions, [:module, :name, :arity])
  end

  def down do
    # Recreate the original table structure with nullable exported
    execute """
    CREATE TABLE functions_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      module TEXT NOT NULL,
      arity INTEGER NOT NULL,
      exported INTEGER,
      path TEXT,
      line INTEGER,
      parsed_at TEXT,
      docs TEXT,
      code TEXT,
      summary TEXT,
      embedding BLOB,
      checksum TEXT,
      marked_for_deletion INTEGER DEFAULT 0 NOT NULL
    )
    """

    execute """
    INSERT INTO functions_new
    SELECT id, name, module, arity, exported, path, line, parsed_at, docs, code, summary, embedding, checksum, marked_for_deletion
    FROM functions
    """

    execute "DROP TABLE functions"
    execute "ALTER TABLE functions_new RENAME TO functions"

    # Recreate the unique index
    create unique_index(:functions, [:module, :name, :arity])
  end
end
