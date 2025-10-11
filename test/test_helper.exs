# Enable compiler tracer for code analysis
Code.put_compiler_option(:tracers, [Codicil.Tracer])

# Run migrations before tests
Ecto.Migrator.run(Codicil.Db.Repo, :code.priv_dir(:codicil) |> Path.join("repo/migrations"), :up,
  all: true
)

ExUnit.start()

# Set up sandbox mode (Repo is already started by the application with sandbox pool in test env)
Ecto.Adapters.SQL.Sandbox.mode(Codicil.Db.Repo, :auto)
