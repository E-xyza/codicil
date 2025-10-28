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

# Configure mock LLM and embeddings clients for testing
# Using nil test_pid for silent operation during application startup
# Individual tests can override these with custom clients if needed
Application.put_env(:codicil, :llm_client, %CodicilTest.LLM.Mock{})
Application.put_env(:codicil, :embeddings_client, %CodicilTest.Embeddings.Mock{})

ExUnit.start()

# Set up sandbox mode (Repo is already started by the application with sandbox pool in test env)
Ecto.Adapters.SQL.Sandbox.mode(Codicil.Db.Repo, :auto)
