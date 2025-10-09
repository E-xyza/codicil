defmodule Codicil.MixProject do
  use Mix.Project

  def project do
    [
      app: :codicil,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [
        tidewave:
          "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4000) end)'"
      ],
      test_elixirc_options: [docs: true]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Codicil.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.17"},
      {:jason, "~> 1.4"},
      {:circular_buffer, "~> 0.4 or ~> 1.0"},
      {:ecto_sql, "~> 3.11"},
      {:ecto_sqlite3, "~> 0.17"},
      {:exqlite, "~> 0.23"},
      {:ecto_enum, "~> 1.4"},
      {:bandit, "~> 1.6", only: [:dev, :test]},
      {:req, "~> 0.5", only: [:test, :dev]},
      {:tidewave, "~> 0.4", only: :dev}
    ]
  end
end
