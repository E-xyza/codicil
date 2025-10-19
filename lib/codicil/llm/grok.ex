defmodule Codicil.LLM.Grok do
  @moduledoc """
  xAI Grok LLM client implementation.

  Uses the xAI API which is OpenAI-compatible.
  """

  @default_model "grok-beta"

  defstruct [
    :api_key,
    model: @default_model
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          model: String.t()
        }

  use Codicil.LLM

  @api_base_url "https://api.x.ai/v1"

  @impl Codicil.LLM
  def generate_text(%__MODULE__{api_key: api_key, model: model}, prompt, opts) do
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

    # Make API request
    case Req.post(
           "#{@api_base_url}/chat/completions",
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ]
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
