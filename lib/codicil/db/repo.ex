defmodule Codicil.Db.Repo do
  use Ecto.Repo,
    otp_app: :codicil,
    adapter: Ecto.Adapters.SQLite3

  def init(_type, config) do
    database_path = Path.join(:code.priv_dir(:codicil), "codicil.db")

    config =
      config
      |> Keyword.put(:database, database_path)
      |> Keyword.put_new(:pool_size, 5)
      |> maybe_use_sandbox_pool()

    {:ok, config}
  end

  defp maybe_use_sandbox_pool(config) do
    if Mix.env() == :test do
      Keyword.put(config, :pool, Ecto.Adapters.SQL.Sandbox)
    else
      config
    end
  end
end
