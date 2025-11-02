defmodule Codicil.MixProject do
  use Mix.Project

  def project do
    [
      app: :codicil,
      version: "0.3.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_elixirc_options: [docs: true],

      # Docs
      name: "Codicil",
      description: "Semantic code search and analysis for Elixir projects via MCP",
      source_url: "https://github.com/E-xyza/codicil",
      homepage_url: "https://github.com/E-xyza/codicil",
      docs: docs(),
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/_support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases(:dev) do
    [
      tidewave:
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4000) end)'"
    ]
  end

  defp aliases(_), do: []

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
      {:protoss, "~> 1.1"},
      {:sqlite_vec, "~> 0.1.0"},
      {:sourceror, "~> 1.0"},
      {:file_system, "~> 1.0"},
      {:bandit, "~> 1.6"},
      {:req, "~> 0.5"},
      {:tidewave, "~> 0.4", only: :dev},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Codicil",
      extras: ["README.md"],
      source_url: "https://github.com/E-xyza/codicil",
      source_ref: "mother",
      formatters: ["html"]
    ]
  end

  defp package do
    [
      description:
        "Semantic code search and analysis for Elixir projects via MCP (Model Context Protocol)",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/E-xyza/codicil",
        "MCP Spec" => "https://spec.modelcontextprotocol.io"
      },
      files: ~w(lib priv/repo .formatter.exs mix.exs README.md LICENSE)
    ]
  end
end
