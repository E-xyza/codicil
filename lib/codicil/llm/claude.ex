defmodule Codicil.LLM.Claude do
  @moduledoc """
  Anthropic Claude LLM client implementation.

  Uses the Anthropic Messages API to generate text completions.
  """

  @default_model "claude-3-5-sonnet-20241022"

  defstruct [
    :api_key,
    model: @default_model
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          model: String.t()
        }

  use Codicil.LLM

  @api_base_url "https://api.anthropic.com/v1"

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
        {:ok, %{status: 200, body: response}} ->
          # Extract text from first content block
          text =
            response
            |> Map.get("content", [])
            |> List.first()
            |> case do
              %{"text" => text} -> text
              _ -> ""
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
