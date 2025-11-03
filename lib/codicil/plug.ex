defmodule Codicil.Plug do
  # A Plug adapter for Codicil MCP server.
  #
  # This module provides HTTP transport for the MCP protocol using Plug.
  @moduledoc false

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn = fetch_query_params(conn)

    case conn.path_info do
      ["codicil", "mcp"] ->
        conn
        |> put_private(:codicil_config, %{
          allowed_origins: nil,
          allow_remote_access: false,
          inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
        })
        |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], json_decoder: Jason))
        |> Codicil.MCP.Server.handle_http_message()

      _ ->
        conn
    end
  end
end
