# Codicil

**Semantic code search and analysis for Elixir projects via MCP (Model Context Protocol)**

Codicil is an Elixir library that provides AI coding assistants with deep semantic understanding of your codebase. Ask questions in natural language, find functions by behavior, trace dependencies, and understand code relationships—all through the Model Context Protocol.

## What does it do?

Imagine asking your AI coding assistant:
- "Find functions that validate user input"
- "Show me what calls this function"
- "What dependencies does this module have?"

Codicil makes this possible by:

1. **Understanding your code** - Analyzes Elixir projects during compilation, extracting functions, modules, and their relationships
2. **Creating semantic search** - Uses AI to understand what code *does*, not just what it's named
3. **Connecting to AI assistants** - Provides tools via MCP that work with Claude, ChatGPT, and other AI coding tools

## Key Features

- **Semantic Function Search** - Find code by describing what it does in plain English
- **Dependency Analysis** - See function call graphs and module relationships
- **Automatic Indexing** - Hooks into compilation, no manual scanning needed
- **Multi-LLM Support** - Works with Anthropic Claude, OpenAI, Cohere, Google Gemini, and Grok

## Installation & Setup

### Common Steps (All Projects)

These steps apply to both Phoenix and non-Phoenix projects.

#### Step 1: Add Dependencies

Add Codicil to your `mix.exs`:

```elixir
def deps do
  [
    # ... your existing dependencies
    {:codicil, "~> 0.1", only: [:dev, :test]}
  ]
end
```

Then install:

```bash
mix deps.get
```

#### Step 2: Initialize the Database

Codicil uses SQLite to store indexed code. Initialize it:

```bash
mix codicil.setup
```

#### Step 3: Configure Environment Variables

Create or edit your `.env` file (or set in your shell):

```bash
# Required: Choose your LLM provider
export CODICIL_LLM_PROVIDER=openai  # or: anthropic, cohere, google, grok

# Required: Add your API key for the chosen provider
export OPENAI_API_KEY=your_key_here
# OR
export ANTHROPIC_API_KEY=your_key_here
# OR
export COHERE_API_KEY=your_key_here
# OR
export GOOGLE_API_KEY=your_key_here

# Optional: Embeddings provider (defaults to openai)
# If you want to use Voyage AI for embeddings:
# export CODICIL_EMBEDDING_PROVIDER=voyage
# export VOYAGE_API_KEY=your_voyage_key_here
```

Load the environment variables:

```bash
source .env
```

#### Step 4: Enable the Compiler Tracer

Edit your `mix.exs` to enable Codicil's tracer in development:

```elixir
def project do
  [
    app: :my_app,
    version: "0.1.0",
    elixir: "~> 1.14",
    # Enable Codicil tracer in dev/test
    elixirc_options: elixirc_options(Mix.env()),
    deps: deps()
  ]
end

defp elixirc_options(:prod), do: []
defp elixirc_options(_env), do: [tracers: [Codicil.Tracer]]
```

This ensures the tracer only runs in development and test, not in production.

---

### Phoenix Project Setup

Continue with these steps if you're using Phoenix.

#### Step 5 (Phoenix): Add MCP Route to Router

Add the Codicil MCP endpoint to your Phoenix router. Edit `lib/my_app_web/router.ex`:

```elixir
defmodule MyAppWeb.Endpoint do

  # ... your endpoint stuff

  # Codicil MCP endpoint (only available when Codicil is loaded)
  if Code.ensure_loaded?(Codicil) do
    plug Codicil.Plug
  end
end
```

#### Step 6 (Phoenix): Start Phoenix and Compile

Start your Phoenix server:

```bash
mix phx.server
```

The MCP server will be available at `http://localhost:4000/codicil/mcp` (or your configured Phoenix port).

Compile your project to trigger indexing:

```bash
# In another terminal
mix compile --force
```

Watch the Phoenix logs to see functions being indexed!

---

### Non-Phoenix Project Setup

Continue with these steps if you're NOT using Phoenix.

#### Step 5 (Non-Phoenix): Add Bandit Dependency

Add Bandit to serve the MCP endpoint. Edit `mix.exs`:

```elixir
def deps do
  [
    # ... your existing dependencies
    {:codicil, "~> 0.1", only: [:dev, :test]},
    {:bandit, "~> 1.6", only: :dev}  # HTTP server for MCP
  ]
end
```

Install:

```bash
mix deps.get
```

#### Step 6 (Non-Phoenix): Add Mix Alias for MCP Server

Add a Mix alias to start the MCP server. Edit your `mix.exs`:

```elixir
def project do
  [
    # ... other config
    aliases: aliases()
  ]
end

defp aliases do
  [
    # ... your existing aliases (if any)
    codicil: "run --no-halt -e 'Bandit.start_link(plug: Codicil.Plug, port: 4700)'"
  ]
end
```

#### Step 7 (Non-Phoenix): Start MCP Server and Compile

Start the MCP server:

```bash
mix codicil
```

The MCP server will start on `http://localhost:4700/codicil/mcp`.

In a second terminal, compile your project to trigger indexing:

```bash
mix compile --force
```

Watch the logs in Terminal 1 to see functions being indexed!

---

## Configure Your AI Assistant

Once Codicil is running, configure your AI assistant (Claude Desktop, Cline, etc.) to connect to the MCP server:

**Phoenix Projects:**
- **URL**: `http://localhost:4000/codicil/mcp` (use your Phoenix port)
- **Transport**: HTTP with SSE

**Non-Phoenix Projects:**
- **URL**: `http://localhost:4700/codicil/mcp`
- **Transport**: HTTP with SSE

The following MCP tools are now available:
- `similar_functions` - Semantic search by description
- `function_callers` - Find what calls a function
- `function_callees` - Find what a function calls
- `module_relationships` - Analyze module dependencies

## Verify It's Working

**Phoenix Projects:**
```bash
# Check that the MCP endpoint is responding
curl http://localhost:4000/codicil/mcp

# Check indexed functions
sqlite3 deps/codicil/priv/codicil.db "SELECT module, name, arity FROM functions LIMIT 10;"
```

**Non-Phoenix Projects:**
```bash
# Check that the MCP server is responding
curl http://localhost:4700/codicil/mcp

# Check indexed functions
sqlite3 deps/codicil/priv/codicil.db "SELECT module, name, arity FROM functions LIMIT 10;"
```

## How It Works

During compilation, Codicil:
1. Captures module/function definitions via `Codicil.Tracer`
2. Extracts documentation and relationships from bytecode
3. Generates semantic summaries using LLMs (rate-limited, async)
4. Creates vector embeddings for semantic search
5. Stores everything in a local SQLite database
6. Watches for file changes and automatically recompiles

Then your AI assistant queries this data through MCP tools.

## Architecture

```
Compilation → Tracer → ModuleTracer GenServer → RateLimiter → LLM/Embeddings
                                              ↓
                                     SQLite Database
                                   (functions, modules,
                                    call graph, vectors)
                                              ↓
                                         MCP Tools
                                              ↓
                                       AI Assistant
```

**Tech Stack:**
- SQLite with `sqlite-vec` extension for vector search
- Ecto for database access
- Compiler tracers for automatic code analysis
- Multiple LLM providers (Anthropic, OpenAI, Cohere, Google, Grok)
- MCP server via Bandit + Plug
- FileSystem watcher for automatic recompilation

## MCP Tool Reference

### similar_functions

Find functions by semantic description:

```json
{
  "description": "functions that validate email addresses",
  "limit": 10
}
```

### function_callers

Find what calls a specific function:

```json
{
  "moduleName": "MyApp.User",
  "functionName": "create",
  "arity": 1
}
```

### function_callees

Find what a function calls:

```json
{
  "moduleName": "MyApp.Orders",
  "functionName": "process",
  "arity": 1
}
```

### module_relationships

Analyze module dependencies (imports, aliases, uses, requires):

```json
{
  "moduleName": "MyApp.Accounts"
}
```

## Advanced Configuration

### Custom Models

Override default models:

```bash
export CODICIL_LLM_MODEL=claude-3-5-sonnet-20241022
export CODICIL_EMBEDDING_MODEL=voyage-3
```

### Separate Embedding Provider

Use a different provider for embeddings:

```bash
export CODICIL_LLM_PROVIDER=anthropic
export CODICIL_EMBEDDING_PROVIDER=openai
export ANTHROPIC_API_KEY=your_claude_key
export OPENAI_API_KEY=your_openai_key
```

### Local LLM Support (OpenAI-compatible)

```bash
export CODICIL_LLM_PROVIDER=openai
export OPENAI_API_KEY=dummy
export OPENAI_BASE_URL=http://localhost:11434/v1  # e.g., Ollama
export CODICIL_LLM_MODEL=llama3
```

## Troubleshooting

### "Functions not being indexed"

**Solution**:
- Verify environment variables are set: `echo $CODICIL_LLM_PROVIDER`
- Check that the MCP server is running: `curl http://localhost:4000/codicil/mcp` (Phoenix) or `curl http://localhost:4700/codicil/mcp` (non-Phoenix)
- Force recompilation: `mix compile --force`
- Check logs for tracer errors

### "Database not found"

**Solution**:
- Initialize the database: `mix codicil.setup`

### "Port 4700 already in use" (Non-Phoenix)

**Solution**:
- Check what's using the port: `lsof -i :4700`
- Kill the process or change the port in your Mix alias

### "Route not found" (Phoenix)

**Solution**: Make sure you added the `forward "/codicil/mcp", Codicil.Plug` route to your Phoenix router and restarted the server.

### Tracer Not Running

**Solution**: Verify the tracer is enabled in your `mix.exs`:
```elixir
defp elixirc_options(_env), do: [tracers: [Codicil.Tracer]]
```

Force a clean recompile:
```bash
mix clean
mix compile
```

## Development

Contributing to Codicil? Here's how to set up the development environment:

```bash
# Clone the repository
git clone https://github.com/yourusername/codicil.git
cd codicil

# Install dependencies
mix deps.get

# Set up database
mix codicil.setup

# Run tests
mix test

# Format code
mix format
```

## Database Schema

Codicil uses SQLite with the following tables:

- **functions** - Function definitions with summaries and embeddings
- **modules** - Module definitions
- **function_calls** - Call graph edges
- **module_dependencies** - Import/alias/use/require relationships

Vector search is powered by the `sqlite-vec` extension.

## Production Warning

**DO NOT deploy Codicil to production.** Codicil is a development tool that:
- Makes LLM API calls (costs money)
- Indexes code at runtime (performance overhead)
- Runs an HTTP server (security surface)

Always include Codicil as a `:dev` only dependency:

```elixir
{:codicil, "~> 0.1", only: [:dev, :test]}
```

The tracer configuration shown above (`elixirc_options(:prod), do: []`) ensures Codicil is disabled in production builds.

## Documentation

Full documentation is available at:
- **HexDocs**: https://hexdocs.pm/codicil
- **MCP Protocol Spec**: https://spec.modelcontextprotocol.io

## Acknowledgments

Codicil is inspired by and based on design patterns from [GraphSense](https://github.com/faraazahmad/graphsense), a TypeScript/Node.js semantic code search tool. GraphSense pioneered the approach of combining vector similarity search with LLM validation for accurate code discovery.

## License

MIT License - see LICENSE file for details.
