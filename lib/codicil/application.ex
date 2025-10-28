defmodule Codicil.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    configure_providers()

    children =
      if Application.spec(:mix, :vsn) do
        [
          Codicil.Db.Repo,
          Codicil.MCP,
          Codicil.RateLimiter,
          {Registry, keys: :unique, name: Codicil.ModuleTracerRegistry},
          {DynamicSupervisor, strategy: :one_for_one, name: Codicil.ModuleTracerSupervisor},
          %{
            id: Codicil.FsWatcher,
            start: {FileSystem, :start_link, [[dirs: [File.cwd!()], name: Codicil.FsWatcher]]}
          },
          Codicil.FileWatcher,
          Codicil.Startup
        ]
      else
        Logger.warning("application :codicil is not starting because Mix is not running")
        []
      end

    opts = [strategy: :one_for_one, name: Codicil.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Provider Configuration
  #
  # Environment variables:
  # - CODICIL_LLM_PROVIDER: openai | anthropic | cohere | google | grok (required)
  # - CODICIL_EMBEDDING_PROVIDER: openai | voyage | cohere | google (optional, defaults to openai)
  # - CODICIL_LLM_MODEL: Override default LLM model (optional)
  # - CODICIL_EMBEDDING_MODEL: Override default embedding model (optional)
  #
  # Provider-specific credentials (required based on provider):
  # - OPENAI_API_KEY
  # - OPENAI_BASE_URL (optional, for local servers like Ollama)
  # - ANTHROPIC_API_KEY
  # - VOYAGE_API_KEY (required if using voyage for embeddings)
  # - COHERE_API_KEY
  # - GOOGLE_API_KEY + GOOGLE_PROJECT_ID

  # Compile-time conditional: no-op in test, full config in dev/prod
  if Mix.env() == :test do
    defp configure_providers, do: :ok
  else
    @default_models %{
      {"openai", :llm} => "gpt-4o",
      {"openai", :embedding} => "text-embedding-3-small",
      {"anthropic", :llm} => "claude-3-5-sonnet-20241022",
      {"voyage", :embedding} => "voyage-3",
      {"cohere", :llm} => "command-a-03-2025",
      {"cohere", :embedding} => "embed-english-v3.0",
      {"google", :llm} => "gemini-2.0-flash",
      {"google", :embedding} => "text-embedding-004"
    }

    defp configure_providers do
      llm_provider = System.fetch_env!("CODICIL_LLM_PROVIDER")
      # Default to same provider as LLM for embeddings (or openai if LLM provider doesn't support embeddings)
      embedding_provider = System.get_env("CODICIL_EMBEDDING_PROVIDER", llm_provider)

      llm_model = System.get_env("CODICIL_LLM_MODEL")
      embedding_model = System.get_env("CODICIL_EMBEDDING_MODEL")

      llm_client = configure_client(llm_provider, llm_model, :llm)
      embeddings_client = configure_client(embedding_provider, embedding_model, :embedding)

      Application.put_env(:codicil, :llm_client, llm_client)
      Application.put_env(:codicil, :embeddings_client, embeddings_client)

      log_configuration(llm_provider, llm_model, embedding_provider, embedding_model)
    end

    defp configure_client(provider, model, type) do
      default_model = Map.fetch!(@default_models, {provider, type})
      model = model || default_model

      case provider do
        "anthropic" ->
          %Codicil.LLM.Anthropic{
            api_key: System.fetch_env!("ANTHROPIC_API_KEY"),
            model: model
          }

        "voyage" ->
          %Codicil.LLM.Voyage{
            api_key: System.fetch_env!("VOYAGE_API_KEY"),
            model: model
          }

        "openai" ->
          %Codicil.LLM.OpenAI{
            api_key: System.get_env("OPENAI_API_KEY"),
            base_url: System.get_env("OPENAI_BASE_URL", "https://api.openai.com/v1"),
            model: model
          }

        "cohere" ->
          %Codicil.LLM.Cohere{
            api_key: System.fetch_env!("COHERE_API_KEY"),
            model: model
          }

        "google" ->
          region = System.get_env("GOOGLE_REGION", "us-central1")

          %Codicil.LLM.Google{
            api_key: System.fetch_env!("GOOGLE_API_KEY"),
            project_id: System.fetch_env!("GOOGLE_PROJECT_ID"),
            model: model,
            region: region
          }

        _ ->
          raise "Unknown provider: #{provider}. Must be one of: anthropic, voyage, openai, cohere, google"
      end
    end

    defp log_configuration(llm_provider, llm_model, embedding_provider, embedding_model) do
      llm_model = llm_model || Map.fetch!(@default_models, {llm_provider, :llm})

      embedding_model =
        embedding_model || Map.fetch!(@default_models, {embedding_provider, :embedding})

      Logger.info("LLM: #{llm_provider} (#{llm_model})")
      Logger.info("Embeddings: #{embedding_provider} (#{embedding_model})")
    end
  end
end
