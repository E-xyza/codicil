defmodule Codicil.Db.Repo.Migrations.CreateFunctionCalls do
  use Ecto.Migration

  def change do
    create table(:function_calls) do
      add :caller_id, references(:functions, on_delete: :delete_all), null: false
      add :callee_id, references(:functions, on_delete: :delete_all), null: false
    end

    create unique_index(:function_calls, [:caller_id, :callee_id])
    create index(:function_calls, [:caller_id])
    create index(:function_calls, [:callee_id])
  end
end
