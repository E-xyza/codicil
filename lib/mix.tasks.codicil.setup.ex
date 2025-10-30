defmodule Mix.Tasks.Codicil.Setup do
  @moduledoc """
  Initializes the Codicil database.

  Creates the database and runs all migrations.

  ## Example

      mix codicil.setup

  """
  @shortdoc "Initializes the Codicil database"

  use Mix.Task

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Setting up Codicil database...")

    # Create the database
    Mix.Task.run("ecto.create", ["-r", "Codicil.Db.Repo"])

    # Run migrations
    Mix.Task.run("ecto.migrate", ["-r", "Codicil.Db.Repo"])

    Mix.shell().info("Codicil database setup complete!")
  end
end
