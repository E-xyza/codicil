defmodule Codicil.LLM.Anthropic do
  # Anthropic client for Claude LLM.
  #
  # Supports:
  # - Text generation via Claude models
  #
  # Note: For embeddings, use Codicil.LLM.Voyage which provides Voyage AI embeddings
  @moduledoc false

  @enforce_keys [:api_key, :model]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          api_key: String.t(),
          model: String.t()
        }

  use Codicil.LLM

  @api_base_url "https://api.anthropic.com/v1"

  # LLM Implementation

  @impl Codicil.LLM
  def generate_text(%__MODULE__{api_key: api_key, model: model}, prompt, opts) do
    max_tokens = Keyword.get(opts, :max_tokens, 1024)
    temperature = Keyword.get(opts, :temperature, 0.7)
    system = Keyword.get(opts, :system)

    # Build messages array
    messages = [
      %{
        role: "user",
        content: prompt
      }
    ]

    # Build request body
    body = %{
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      messages: messages
    }

    body =
      if system do
        Map.put(body, :system, system)
      else
        body
      end

    # Make API request
    case Req.post(
           "#{@api_base_url}/messages",
           json: body,
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", "2023-06-01"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: response}} when status >= 200 and status <= 299 ->
        # Extract text from first content block
        text =
          response
          |> Map.get("content", [])
          |> List.first()
          |> case do
            %{"text" => text} -> text
            _ -> ""
          end

        # Log token usage
        if usage = Map.get(response, "usage") do
          input_tokens = Map.get(usage, "input_tokens", 0)
          output_tokens = Map.get(usage, "output_tokens", 0)
          require Logger

          Logger.info(
            "Anthropic LLM call - Model: #{model}, Input tokens: #{input_tokens}, Output tokens: #{output_tokens}, Total: #{input_tokens + output_tokens}"
          )
        end

        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        error_message = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, error_message}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
