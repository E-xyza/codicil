ExUnit.start()

# Set up sandbox mode (Repo is already started by the application with sandbox pool in test env)
Ecto.Adapters.SQL.Sandbox.mode(Codicil.Db.Repo, :auto)
