defmodule Codicil.MCP.ServerTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  @moduletag :capture_log

  describe "handle_message/1" do
    setup do
      # Create a simple conn with the needed configuration
      conn =
        conn(:post, "/codicil/mcp", %{})
        |> put_req_header("content-type", "application/json")
        |> put_private(:codicil_config, %{
          allowed_origins: nil,
          allow_remote_access: false,
          inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
        })

      %{conn: conn}
    end

    test "handles initialization message", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "id" => "1",
        "params" => %{
          "protocolVersion" => "2025-03-26",
          "capabilities" => %{
            "version" => "1.0"
          }
        }
      }

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["jsonrpc"] == "2.0"
      assert response_body["id"] == "1"
      assert response_body["result"]["protocolVersion"] == "2025-03-26"
      assert is_list(response_body["result"]["tools"])
      assert response_body["result"]["serverInfo"]["name"] == "Codicil MCP Server"
    end

    test "handles initialized notification", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 202
      assert response.resp_body == "{\"status\":\"ok\"}"
    end

    test "handles cancelled notification", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/cancelled",
        "params" => %{"reason" => "test"}
      }

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 202
      assert response.resp_body == "{\"status\":\"ok\"}"
    end

    test "handles ping request", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "ping",
        "id" => "ping-1"
      }

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["jsonrpc"] == "2.0"
      assert response_body["id"] == "ping-1"
      assert response_body["result"] == %{}
    end

    test "handles tools/list request", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => "2"
      }

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["jsonrpc"] == "2.0"
      assert response_body["id"] == "2"
      assert is_list(response_body["result"]["tools"])
      # Should have 6 registered tools
      assert length(response_body["result"]["tools"]) == 6

      # Verify tool names
      tool_names = Enum.map(response_body["result"]["tools"], & &1["name"])
      assert "find_similar_functions" in tool_names
      assert "list_function_callers" in tool_names
      assert "list_function_callees" in tool_names
      assert "list_module_dependencies" in tool_names
      assert "list_module_dependents" in tool_names
      assert "get_function_source_code" in tool_names
    end

    test "returns error for invalid JSON-RPC message", %{conn: conn} do
      message = %{"invalid" => "message"}

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["error"]["code"] == -32600
      assert response_body["error"]["message"] == "Could not parse message"
    end

    test "returns error for unsupported method", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "unsupported/method",
        "id" => "4"
      }

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 400
      response_body = Jason.decode!(response.resp_body)
      assert response_body["error"]["code"] == -32601
      assert response_body["error"]["message"] == "Method not found"
    end

    test "validates protocol version", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "id" => "5",
        "params" => %{
          "protocolVersion" => "2024-01-01",
          "capabilities" => %{}
        }
      }

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 400
      response_body = Jason.decode!(response.resp_body)
      assert response_body["error"]
    end

    test "requires protocol version in initialize", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "id" => "6",
        "params" => %{
          "capabilities" => %{}
        }
      }

      conn = %{conn | body_params: message}
      response = Codicil.MCP.Server.handle_http_message(conn)

      assert response.status == 400
      response_body = Jason.decode!(response.resp_body)
      assert response_body["error"]
    end
  end
end
