defmodule Codicil.LLM.OpenAI do
  @moduledoc """
  OpenAI-compatible LLM client implementation.

  Supports OpenAI API and compatible endpoints (Ollama, LM Studio, etc.).
  Can be used with or without authentication for local models.
  """

  @default_base_url "https://api.openai.com/v1"

  defstruct [
    :api_key,
    :model,
    base_url: @default_base_url
  ]

  @type t :: %__MODULE__{
          api_key: String.t() | nil,
          model: String.t(),
          base_url: String.t()
        }

  use Codicil.LLM

  @impl Codicil.LLM
  def generate_text(%__MODULE__{api_key: api_key, model: model, base_url: base_url}, prompt, opts) do
      max_tokens = Keyword.get(opts, :max_tokens, 1024)
      temperature = Keyword.get(opts, :temperature, 0.7)
      system = Keyword.get(opts, :system)

      # Build messages array
      messages =
        if system do
          [
            %{role: "system", content: system},
            %{role: "user", content: prompt}
          ]
        else
          [%{role: "user", content: prompt}]
        end

      # Build request body
      body = %{
        model: model,
        messages: messages,
        max_tokens: max_tokens,
        temperature: temperature
      }

      # Build headers - include auth only if api_key is present
      headers =
        [{"content-type", "application/json"}] ++
          if api_key do
            [{"authorization", "Bearer #{api_key}"}]
          else
            []
          end

      # Make API request
      case Req.post(
             "#{base_url}/chat/completions",
             json: body,
             headers: headers
           ) do
        {:ok, %{status: 200, body: response}} ->
          # Extract text from first choice
          text =
            response
            |> Map.get("choices", [])
            |> List.first()
            |> case do
              %{"message" => %{"content" => content}} -> content
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
