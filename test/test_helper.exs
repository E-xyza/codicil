# NOTE: Tracer is NOT enabled in test_helper to avoid database contention
# during parallel test compilation. Specific tracer tests can enable it locally.

# Set logger level to :error to reduce noise in test output
Logger.configure(level: :error)

# Run migrations before tests
Ecto.Migrator.run(Codicil.Db.Repo, :code.priv_dir(:codicil) |> Path.join("repo/migrations"), :up,
  all: true
)

# Configure callback for writing beam files in tests so Code.fetch_docs can find them
Application.put_env(:codicil, :predoc_callback, fn module, bytecode ->
  beam_dir = Path.join([File.cwd!(), "test", "_support", "beamfiles"])
  File.mkdir_p!(beam_dir)

  beam_filename = "#{module}.beam"
  beam_path = Path.join(beam_dir, beam_filename)
  File.write!(beam_path, bytecode)

  # Add directory to code path
  :code.add_pathz(String.to_charlist(beam_dir))
end)

ExUnit.start()

# Set up sandbox mode (Repo is already started by the application with sandbox pool in test env)
Ecto.Adapters.SQL.Sandbox.mode(Codicil.Db.Repo, :auto)
