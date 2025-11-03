defmodule Codicil do
  @moduledoc """
  Semantic code search and analysis for Elixir projects via MCP (Model Context Protocol).

  Codicil provides AI coding assistants with deep semantic understanding of your codebase through:

  - **Semantic function search** - Find code by describing what it does in natural language
  - **Dependency analysis** - Trace function call graphs and module relationships
  - **Automatic indexing** - Hooks into compilation to analyze code as you build
  - **Multi-LLM support** - Works with Anthropic Claude, OpenAI, Cohere, Google Gemini, and Grok

  ## Quick Start

  ### 1. Add Codicil to your dependencies

  ```elixir
  def deps do
    [
      {:codicil, "~> 0.4", only: [:dev, :test]}
    ]
  end
  ```

  ### 2. Initialize the database

  ```bash
  mix deps.get
  mix codicil.setup
  ```

  ### 3. Configure environment variables

  ```bash
  export CODICIL_LLM_PROVIDER=openai  # or: anthropic, cohere, google, grok
  export OPENAI_API_KEY=your_key_here

  # Optional: Separate embeddings provider (defaults to openai)
  # export CODICIL_EMBEDDING_PROVIDER=voyage
  # export VOYAGE_API_KEY=your_voyage_key_here
  ```

  ### 4. Enable the compiler tracer

  Edit your `mix.exs`:

  ```elixir
  def project do
    [
      app: :my_app,
      elixirc_options: elixirc_options(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_options(:prod), do: []
  defp elixirc_options(_env), do: [tracers: [Codicil.Tracer]]
  ```

  ### 5. Set up the MCP endpoint

  **For Phoenix projects**, add to your endpoint:

  ```elixir
  if Code.ensure_loaded?(Codicil) do
    plug Codicil.Plug
  end
  ```

  **For non-Phoenix projects**, add Bandit and a Mix alias:

  ```elixir
  # In deps
  {:bandit, "~> 1.6", only: :dev}

  # In aliases
  codicil: "run --no-halt -e 'Bandit.start_link(plug: Codicil.Plug, port: 4700)'"
  ```

  Then run `mix codicil` to start the MCP server.

  **To combine multiple MCP servers** (e.g., Codicil + Tidewave):

  ```elixir
  # In aliases
  mcp: "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Codicil.Plug, port: 4700); Bandit.start_link(plug: Tidewave, port: 4000) end)'"
  ```

  ### 6. Compile your project

  ```bash
  mix compile --force
  ```

  Codicil will automatically index your code and make it available to AI assistants.

  ## MCP Tools

  Once configured, your AI assistant can use these tools:

  - `find_similar_functions` - Find functions by semantic description
  - `list_function_callers` - Find what calls a specific function (useful for debugging and refactoring)
  - `list_function_callees` - Find what a function calls (useful for debugging and refactoring)
  - `list_module_dependencies` - Analyze module dependencies
  - `get_module_file_path` - Get file path for a module (use instead of `ls` or `grep`)
  - `get_function_source_code` - Get complete function source with context (use instead of `grep`)

  ## Configuration

  Set these environment variables to customize Codicil:

  - `CODICIL_LLM_PROVIDER` - LLM provider (required): `openai`, `anthropic`, `cohere`, `google`, `grok`
  - `CODICIL_LLM_MODEL` - Override default model for summaries
  - `CODICIL_EMBEDDING_PROVIDER` - Separate provider for embeddings (defaults to same as LLM provider)
  - `CODICIL_EMBEDDING_MODEL` - Override default embedding model

  Provider-specific API keys:
  - `OPENAI_API_KEY` - For OpenAI (default)
  - `OPENAI_BASE_URL` - For OpenAI-compatible local models (e.g., Ollama)
  - `ANTHROPIC_API_KEY` - For Anthropic Claude
  - `VOYAGE_API_KEY` - For Voyage AI embeddings (if using voyage provider)
  - `COHERE_API_KEY` - For Cohere
  - `GOOGLE_API_KEY` - For Google Gemini

  ## How It Works

  Codicil uses Elixir's compiler tracer system to capture code structure during compilation:

  1. The compiler tracer receives compilation events for all modules and functions
  2. Extracted metadata is processed by dedicated GenServers per module
  3. Functions are queued for LLM processing with rate limiting
  4. Summaries and embeddings are generated and stored in SQLite
  5. A file watcher monitors changes and triggers recompilation
  6. AI assistants query the indexed code via MCP tools over HTTP

  ## Production Warning

  **DO NOT deploy Codicil to production.** It is a development tool that:
  - Makes LLM API calls (costs money)
  - Indexes code at runtime (performance overhead)
  - Runs an HTTP server (security surface)

  Always include Codicil as a `:dev` and `:test` only dependency.

  ## Documentation

  For detailed setup instructions, troubleshooting, and advanced configuration, see:
  - [README.md](readme.html) - Complete installation and setup guide
  - [MCP Protocol Spec](https://spec.modelcontextprotocol.io) - Model Context Protocol specification
  """
end
