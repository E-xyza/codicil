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

  defp init_config do
    :ok
  end
end
