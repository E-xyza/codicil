defmodule Codicil.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children =
      if Application.spec(:mix, :vsn) do
        [
          Codicil.Db.Repo,
          Codicil.MCP,
          Codicil.RateLimiter,
          {Registry, keys: :unique, name: Codicil.ModuleTracerRegistry},
          {DynamicSupervisor, strategy: :one_for_one, name: Codicil.ModuleTracerSupervisor}
        ]
      else
        Logger.warning("application :codicil is not starting because Mix is not running")
        []
      end

    opts = [strategy: :one_for_one, name: Codicil.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
