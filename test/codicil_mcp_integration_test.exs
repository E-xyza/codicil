defmodule Codicil.MCPIntegrationTest do
  use ExUnit.Case, async: false
  require Logger

  @base_url "http://localhost:9101/codicil/mcp"

  @moduletag :capture_log

  setup _context do
    start_supervised!(
      {Bandit, plug: Codicil.Plug, port: 9101, startup_log: false},
      shutdown: 10
    )

    assert Stream.interval(10)
           |> Stream.take(10)
           |> Enum.reduce_while(nil, fn _, _ ->
             case Req.post("http://127.0.0.1:9101") do
               {:ok, _} -> {:halt, true}
               _ -> {:cont, false}
             end
           end),
           "server not listening"

    %{tools: initialize_and_get_tools()}
  end

  test "connects to HTTP endpoint and receives tools on initialize", %{tools: tools} do
    assert is_list(tools)
    # Should have 4 registered tools
    assert length(tools) == 4

    # Verify tool names
    tool_names = Enum.map(tools, & &1["name"])
    assert "similar_functions" in tool_names
    assert "function_callers" in tool_names
    assert "function_callees" in tool_names
    assert "module_relationships" in tool_names
  end

  test "handles ping request" do
    id = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "ping"
      })

    assert response["id"] == id
    assert response["result"] == %{}
  end

  test "handles tools/list request" do
    id = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "tools/list"
      })

    assert response["id"] == id
    assert is_list(response["result"]["tools"])
    # Should have 4 registered tools
    assert length(response["result"]["tools"]) == 4
  end

  test "returns error for invalid method" do
    id = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "invalid/method"
      })

    assert response["id"] == id
    assert response["error"]["code"] == -32601
    assert response["error"]["message"] == "Method not found"
  end

  test "returns error for non-existent tool" do
    id = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "tools/call",
        "params" => %{
          "name" => "non_existent_tool",
          "arguments" => %{}
        }
      })

    assert response["id"] == id
    # Tool not found should return success with isError: true
    assert response["result"]["isError"] == true
  end

  test "validates protocol version" do
    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => "invalid-version",
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2020-01-01",
          "capabilities" => %{}
        }
      })

    assert response["error"]
  end

  ### helpers

  defp initialize_and_get_tools() do
    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => "init",
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2025-03-26",
          "capabilities" => %{}
        }
      })

    assert response["jsonrpc"] == "2.0"
    assert response["id"] == "init"
    assert response["result"]["tools"]
    assert response["result"]["serverInfo"]["name"] == "Codicil MCP Server"
    assert response["result"]["serverInfo"]["version"] == "0.2.1"

    response["result"]["tools"]
  end

  defp send_http_request(message) do
    {:ok, http_response} = Req.post(@base_url, json: message)
    assert http_response.body

    http_response.body
  end
end
