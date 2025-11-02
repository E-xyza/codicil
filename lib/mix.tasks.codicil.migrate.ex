defmodule Mix.Tasks.Codicil.Migrate do
  @moduledoc """
  Runs Codicil database migrations.

  ## Example

      mix codicil.migrate

  """
  @shortdoc "Runs Codicil database migrations"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Signal to tracer not to start the application during migration
    Application.put_env(:codicil, :skip_startup, true)

    Mix.shell().info("Running Codicil database migrations...")

    # Run migrations
    Mix.Task.run("ecto.migrate", ["-r", "Codicil.Db.Repo"] ++ args)

    Mix.shell().info("Codicil database migrations complete!")
  end
end
