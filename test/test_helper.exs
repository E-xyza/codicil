# NOTE: Tracer is NOT enabled in test_helper to avoid database contention
# during parallel test compilation. Specific tracer tests can enable it locally.

# Run migrations before tests
Ecto.Migrator.run(Codicil.Db.Repo, :code.priv_dir(:codicil) |> Path.join("repo/migrations"), :up,
  all: true
)

ExUnit.start()

# Set up sandbox mode (Repo is already started by the application with sandbox pool in test env)
Ecto.Adapters.SQL.Sandbox.mode(Codicil.Db.Repo, :auto)
