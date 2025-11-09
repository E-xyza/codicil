defmodule Codicil.MCP.Server do
  @moduledoc false

  require Logger

  alias Codicil.MCP.Tool
  alias Codicil.MCP.Tools.FindSimilarFunctions
  alias Codicil.MCP.Tools.GetFunctionSourceCode
  alias Codicil.MCP.Tools.ListFunctionCallees
  alias Codicil.MCP.Tools.ListFunctionCallers
  alias Codicil.MCP.Tools.ListModuleDependencies

  import Plug.Conn

  @protocol_version "2025-03-26"
  @vsn Mix.Project.config()[:version]

  ## Tool management functions

  defp raw_tools do
    [
      %{
        name: "find_similar_functions",
        description: Tool.get_description(FindSimilarFunctions),
        inputSchema: %{
          type: "object",
          properties: %{
            description: %{
              type: "string",
              description: "Natural language description of the desired functionality"
            },
            limit: %{
              type: "number",
              description: "Maximum number of results to return (default: 10)"
            },
            batch_size: %{
              type: "number",
              description: "Number of functions to validate per LLM call (default: 20)"
            },
            vector_limit: %{
              type: "number",
              description: "Number of candidates to retrieve from vector search (default: 100)"
            }
          },
          required: ["description"]
        },
        callback: &FindSimilarFunctions.call/1
      },
      %{
        name: "list_function_callers",
        description: Tool.get_description(ListFunctionCallers),
        inputSchema: %{
          type: "object",
          properties: %{
            functionName: %{
              type: "string",
              description: "Name of the target function (e.g., 'calculate_total')"
            },
            moduleName: %{
              type: "string",
              description: "Module name (e.g., 'MyApp.Calculator' or ':gen_server')"
            },
            arity: %{
              type: "number",
              description: "Function arity (number of arguments)"
            }
          },
          required: ["functionName", "moduleName", "arity"]
        },
        callback: &ListFunctionCallers.call/1
      },
      %{
        name: "list_function_callees",
        description: Tool.get_description(ListFunctionCallees),
        inputSchema: %{
          type: "object",
          properties: %{
            functionName: %{
              type: "string",
              description: "Name of the source function (e.g., 'process_order')"
            },
            moduleName: %{
              type: "string",
              description: "Module name (e.g., 'MyApp.Orders' or ':gen_server')"
            },
            arity: %{
              type: "number",
              description: "Function arity (number of arguments)"
            }
          },
          required: ["functionName", "moduleName", "arity"]
        },
        callback: &ListFunctionCallees.call/1
      },
      %{
        name: "list_module_dependencies",
        description: Tool.get_description(ListModuleDependencies),
        inputSchema: %{
          type: "object",
          properties: %{
            moduleName: %{
              type: "string",
              description: "Module name (e.g., 'MyApp.User' or ':gen_server')"
            },
            type: %{
              type: "string",
              description:
                "Optional filter: 'compiler' for compile-time or 'runtime' for runtime dependencies",
              enum: ["compiler", "runtime"]
            }
          },
          required: ["moduleName"]
        },
        callback: &ListModuleDependencies.call/1
      },
      %{
        name: "get_function_source_code",
        description: Tool.get_description(GetFunctionSourceCode),
        inputSchema: %{
          type: "object",
          properties: %{
            moduleName: %{
              type: "string",
              description: "Module name (e.g., 'MyApp.User' or ':gen_server')"
            },
            functionName: %{
              type: "string",
              description: "Function name (e.g., 'process_order')"
            },
            arity: %{
              type: "number",
              description: "Function arity (number of arguments)"
            }
          },
          required: ["moduleName", "functionName", "arity"]
        },
        callback: &GetFunctionSourceCode.call/1
      }
    ]
  end

  @doc false
  def init_tools do
    tools = raw_tools()
    dispatch_map = Map.new(tools, fn tool -> {tool.name, tool.callback} end)

    :ets.new(:codicil_tools, [:set, :named_table, read_concurrency: true])
    :ets.insert(:codicil_tools, {:tools, {tools, dispatch_map}})
  end

  @doc false
  def tools_and_dispatch do
    [{:tools, tools}] = :ets.lookup(:codicil_tools, :tools)
    tools
  end

  defp tools() do
    {tools, _} = tools_and_dispatch()

    for tool <- tools do
      tool
      |> Map.put(:description, String.trim(tool.description))
      |> Map.drop([:callback])
    end
  end

  # A callback must return either
  #
  #   * `{:ok, result}` if the callback does not receive state
  #   * `{:ok, result, new_state}` if the callback receives state (i.e. if it is of arity 2)
  #   * `{:ok, result, metadata}` if the callback is of arity 1 and returns metadata (returned as `_meta`)
  #   * `{:ok, result, new_state, metadata}` if the callback is of arity 2 and returns metadata (returned as `_meta`)
  #   * `{:error, reason}` for any error
  #   * `{:error, reason, new_state}` for any error that should also update the state
  #
  defp dispatch(name, args, assigns) do
    {_tools, dispatch} = tools_and_dispatch()

    case dispatch do
      %{^name => callback} when is_function(callback, 2) ->
        callback.(args, assigns)

      %{^name => callback} when is_function(callback, 1) ->
        callback.(args)

      _ ->
        {:error,
         %{
           code: -32601,
           message: "Method not found",
           data: %{
             name: name
           }
         }}
    end
  end

  ## MCP message processing

  defp validate_protocol_version(client_version) do
    cond do
      is_nil(client_version) ->
        {:error, "Protocol version is required"}

      client_version < unquote(@protocol_version) ->
        {:error,
         "Unsupported protocol version. Server supports #{unquote(@protocol_version)} or later"}

      :else ->
        :ok
    end
  end

  defp handle_ping(request_id) do
    {:ok,
     %{
       jsonrpc: "2.0",
       id: request_id,
       result: %{}
     }}
  end

  defp handle_initialize(request_id, params) do
    case validate_protocol_version(params["protocolVersion"]) do
      :ok ->
        {:ok,
         %{
           jsonrpc: "2.0",
           id: request_id,
           result: %{
             protocolVersion: @protocol_version,
             capabilities: %{
               tools: %{
                 listChanged: false
               }
             },
             serverInfo: %{
               name: "Codicil MCP Server",
               version: @vsn
             },
             tools: tools()
           }
         }}

      {:error, reason} when is_binary(reason) ->
        {:error,
         %{
           jsonrpc: "2.0",
           id: request_id,
           error: %{
             code: -32602,
             message: reason
           }
         }}
    end
  end

  defp handle_list_tools(request_id, _params) do
    result_or_error(request_id, {:ok, %{tools: tools()}})
  end

  defp result_or_error(request_id, {:ok, text, metadata})
       when is_binary(text) and is_map(metadata) do
    result_or_error(request_id, {:ok, %{content: [%{type: "text", text: text}], _meta: metadata}})
  end

  defp result_or_error(request_id, {:ok, text}) when is_binary(text) do
    result_or_error(request_id, {:ok, %{content: [%{type: "text", text: text}]}})
  end

  defp result_or_error(request_id, {:ok, result}) when is_map(result) do
    {:ok,
     %{
       jsonrpc: "2.0",
       id: request_id,
       result: result
     }}
  end

  defp result_or_error(request_id, {:error, :invalid_arguments}) do
    {:error,
     %{
       jsonrpc: "2.0",
       id: request_id,
       error: %{code: -32602, message: "Invalid arguments for tool"}
     }}
  end

  defp result_or_error(request_id, {:error, message}) when is_binary(message) do
    # tool errors should be treated as successful response with isError: true
    # https://spec.modelcontextprotocol.io/specification/2024-11-05/server/tools/#error-handling
    result_or_error(
      request_id,
      {:ok, %{content: [%{type: "text", text: message}], isError: true}}
    )
  end

  defp result_or_error(request_id, {:error, %{code: -32601} = error}) do
    # Tool not found - return as successful response with isError: true per MCP spec
    result_or_error(
      request_id,
      {:ok, %{content: [%{type: "text", text: error.message}], isError: true}}
    )
  end

  defp result_or_error(request_id, {:error, error}) when is_map(error) do
    {:error,
     %{
       jsonrpc: "2.0",
       id: request_id,
       error: error
     }}
  end

  defp handle_call_tool(request_id, %{"name" => name} = params, assigns) do
    args = Map.get(params, "arguments", %{})
    Logger.info("MCP tool call: #{name} with args: #{inspect(args)}")
    result = dispatch(name, args, assigns)

    case result do
      {:ok, _} -> Logger.info("MCP tool call succeeded: #{name}")
      {:error, reason} -> Logger.warning("MCP tool call failed: #{name} - #{inspect(reason)}")
    end

    result_or_error(request_id, result)
  end

  defp safe_call_tool(request_id, params, assigns) do
    handle_call_tool(request_id, params, assigns)
  catch
    kind, reason ->
      # tool exceptions should be treated as successful response with isError: true
      # https://spec.modelcontextprotocol.io/specification/2024-11-05/server/tools/#error-handling
      {:ok,
       %{
         jsonrpc: "2.0",
         id: request_id,
         result: %{
           content: [
             %{
               type: "text",
               text: "Failed to call tool: #{Exception.format(kind, reason, __STACKTRACE__)}"
             }
           ],
           isError: true
         }
       }}
  end

  # Built-in message routing
  defp handle_message(%{"method" => "notifications/initialized"} = message, _assigns) do
    Logger.info("Received initialized notification")
    Logger.debug("Full message: #{inspect(message, pretty: true)}")
    {:ok, nil}
  end

  defp handle_message(%{"method" => "notifications/cancelled"} = message, _assigns) do
    Logger.info("Request cancelled: #{inspect(message["params"])}")
    {:ok, nil}
  end

  defp handle_message(%{"method" => method, "id" => id} = message, assigns) do
    Logger.info("Routing MCP message - Method: #{method}, ID: #{id}")
    Logger.debug("Full message: #{inspect(message, pretty: true)}")

    case method do
      "ping" ->
        Logger.debug("Handling ping request")
        handle_ping(id)

      "initialize" ->
        Logger.info(
          "Handling initialize request with params: #{inspect(message["params"], pretty: true)}"
        )

        handle_initialize(id, message["params"])

      "tools/list" ->
        Logger.debug("Handling tools list request")
        handle_list_tools(id, message["params"])

      "tools/call" ->
        Logger.debug(
          "Handling tool call request with params: #{inspect(message["params"], pretty: true)}"
        )

        safe_call_tool(id, message["params"], assigns)

      other ->
        Logger.warning("Received unsupported method: #{other}")

        {:error,
         %{
           jsonrpc: "2.0",
           id: id,
           error: %{
             code: -32601,
             message: "Method not found",
             data: %{
               name: other
             }
           }
         }}
    end
  end

  ## HTTP transport functions

  defp validate_jsonrpc_message(%{"jsonrpc" => "2.0"} = message) do
    cond do
      # Request must have method and id (string or number)
      Map.has_key?(message, "id") and Map.has_key?(message, "method") ->
        case message["id"] do
          id when is_binary(id) or is_number(id) -> {:ok, message}
          _ -> {:error, :invalid_jsonrpc}
        end

      # Notification must have method but no id
      not Map.has_key?(message, "id") and Map.has_key?(message, "method") ->
        {:ok, message}

      # reply (e.g. to ping) with ID + result
      Map.has_key?(message, "id") and Map.has_key?(message, "result") ->
        {:ok, message}

      :else ->
        {:error, :invalid_jsonrpc}
    end
  end

  defp validate_jsonrpc_message(_), do: {:error, :invalid_jsonrpc}

  defp send_json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
    |> halt()
  end

  defp send_jsonrpc_error(conn, id, code, message, data \\ nil) do
    error = %{
      code: code,
      message: message
    }

    error = if data, do: Map.put(error, :data, data), else: error

    response = %{
      jsonrpc: "2.0",
      id: id,
      error: error
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
    |> halt()
  end

  def handle_http_message(conn) do
    Logger.info("Received #{conn.method} message")
    params = conn.body_params
    conn = fetch_query_params(conn)
    Logger.debug("Raw params: #{inspect(params, pretty: true)}")

    case validate_jsonrpc_message(params) do
      {:ok, message} ->
        assigns = conn.private.codicil_config

        case handle_message(message, assigns) do
          {:ok, nil} ->
            # Notifications that don't return a response
            conn |> put_status(202) |> send_json(%{status: "ok"})

          {:ok, response} ->
            Logger.debug("Sending HTTP response: #{inspect(response, pretty: true)}")
            conn |> put_status(200) |> send_json(response)

          {:error, error_response} ->
            Logger.warning("Error handling message: #{inspect(error_response)}")
            conn |> put_status(400) |> send_json(error_response)
        end

      {:error, :invalid_jsonrpc} ->
        Logger.warning("Invalid JSON-RPC message format")
        send_jsonrpc_error(conn, nil, -32600, "Could not parse message")
    end
  end
end
