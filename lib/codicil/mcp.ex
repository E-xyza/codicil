defmodule Codicil.MCP do
  @moduledoc false

  use Supervisor
  require Logger

  alias Codicil.MCP

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    maybe_silence_logs()
    add_logger_backend()
    init_config()

    MCP.Server.init_tools()

    children = [
      {Registry, name: MCP.Registry, keys: :unique},
      Codicil.MCP.Logger,
      {Codicil.MCP.IOForwardGL, name: :standard_error}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the working directory.
  """
  def root, do: Application.fetch_env!(:codicil, :root)

  @doc """
  Returns the git root if any.
  """
  def git_root, do: Application.fetch_env!(:codicil, :git_root)

  @doc """
  Returns the project name.
  """
  def project_name, do: Application.fetch_env!(:codicil, :project_name)

  @doc """
  Normalizes a module name from user input to internal Elixir format.

  ## Examples

      iex> Codicil.MCP.normalize_module_name("MyApp.User")
      "Elixir.MyApp.User"

      iex> Codicil.MCP.normalize_module_name(":gen_server")
      "gen_server"

      iex> Codicil.MCP.normalize_module_name("Elixir.MyApp.User")
      "Elixir.MyApp.User"
  """
  def normalize_module_name(name) when is_binary(name) do
    cond do
      # Already has Elixir. prefix - keep as-is
      String.starts_with?(name, "Elixir.") ->
        name

      # Starts with : - it's an atom, remove the colon
      String.starts_with?(name, ":") ->
        String.slice(name, 1..-1//1)

      # Starts with capital letter - it's an Elixir alias, add prefix
      String.match?(name, ~r/^[A-Z]/) ->
        "Elixir." <> name

      # Otherwise, keep as-is
      :else ->
        name
    end
  end

  defp maybe_silence_logs do
    if Application.get_env(:codicil, :debug) do
      :ok
    else
      Logger.put_module_level(MCP.Connection, :none)
      Logger.put_module_level(MCP.Server, :none)
    end
  end

  defp add_logger_backend() do
    :ok =
      :logger.add_handler(
        MCP.Logger,
        MCP.Logger,
        %{formatter: Logger.default_formatter(colors: [enabled: false])}
      )
  end

  # Compile-time conditional: attempt to get project name from Mix in dev/test, require config in prod
  if Mix.env() in [:dev, :test] do
    defp maybe_set_project_name do
      if module = Mix.Project.get() do
        project_name = module |> Module.split() |> hd() |> Macro.underscore()
        Application.put_env(:codicil, :project_name, project_name)
      else
        raise """
        codicil could not determine the current project, please specify a name in your config.exs:

            config :codicil, :project_name, "my_project"
        """
      end
    end
  else
    defp maybe_set_project_name do
      raise """
      codicil could not determine the current project, please specify a name in your config.exs:

          config :codicil, :project_name, "my_project"
      """
    end
  end

  defp init_config() do
    if Application.get_env(:codicil, :root) == nil do
      Application.put_env(:codicil, :root, File.cwd!())
    end

    if System.find_executable("git") &&
         match?({_, 0}, System.cmd("git", ["rev-parse", "--show-toplevel"])) do
      {git_root, 0} = System.cmd("git", ["rev-parse", "--show-toplevel"])
      Application.put_env(:codicil, :git_root, String.trim(git_root))
    else
      Logger.warning(
        "Some Codicil tools are only available for codebases using `git`. " <>
          "Make sure `git` is installed and run `git init` before continuing"
      )
    end

    if Application.get_env(:codicil, :project_name) == nil do
      maybe_set_project_name()
    end
  end
end
