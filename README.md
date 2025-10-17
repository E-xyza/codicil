# Codicil

**Semantic code search and analysis for Elixir projects via MCP (Model Context Protocol)**

Codicil is an Elixir library that provides AI coding assistants with deep semantic understanding of your codebase. Ask questions in natural language, find functions by behavior, trace dependencies, and understand code relationships—all through the Model Context Protocol.

## For Everyone

### What does it do?

Imagine asking your AI coding assistant:
- "Find functions that validate user input"
- "Show me what calls this function"
- "What dependencies does this module have?"

Codicil makes this possible by:

1. **Understanding your code** - Analyzes Elixir projects during compilation, extracting functions, modules, and their relationships
2. **Creating semantic search** - Uses AI to understand what code *does*, not just what it's named
3. **Connecting to AI assistants** - Provides tools via MCP that work with Claude, ChatGPT, and other AI coding tools

### Key Features

- **Semantic Function Search** - Find code by describing what it does in plain English
- **Dependency Analysis** - See function call graphs and module relationships
- **Zero Config** - Just compile your project with the tracer enabled
- **Multi-LLM Support** - Works with Anthropic Claude, OpenAI, Cohere, Google Gemini, and Grok

## For Elixir Developers

### How it works

Codicil hooks into Elixir's compilation process using compiler tracers:

```elixir
# In your project's config (optional - see below)
Code.put_compiler_option(:tracers, [Codicil.Tracer])
```

During compilation, Codicil:
1. Captures module/function definitions and relationships via `Codicil.Tracer`
2. Extracts documentation and line numbers from source files
3. Analyzes bytecode to build function call graphs
4. Generates semantic summaries using LLMs (rate-limited, async)
5. Creates vector embeddings for semantic search
6. Stores everything in a local SQLite database

Then your AI assistant can query this data through MCP tools:
- `similar_functions` - Semantic search with vector similarity + LLM validation
- `function_callers` - Find reverse dependencies
- `function_callees` - Find forward dependencies
- `module_relationships` - Analyze imports, aliases, uses, requires

### Architecture

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
- Compiler tracers for code analysis
- Multiple LLM providers (Anthropic, OpenAI, Cohere, Google, Grok)
- MCP server via Bandit + Plug

### Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:codicil, "~> 0.1", only: :dev},
    {:bandit, "~> 1.6", only: :dev}
  ]
end
```

### Configuration

Set environment variables for your LLM provider:

```bash
# Required: Choose your LLM provider
export CODICIL_LLM_PROVIDER=anthropic  # or openai, cohere, google

# Provider-specific API keys
export ANTHROPIC_API_KEY=your_key_here
# OR
export OPENAI_API_KEY=your_key_here
export OPENAI_BASE_URL=https://api.openai.com/v1  # optional, for local models
# OR
export COHERE_API_KEY=your_key_here
# OR
export GOOGLE_API_KEY=your_key_here
export GOOGLE_PROJECT_ID=your_project_id

# Optional: Separate embedding provider
export CODICIL_EMBEDDING_PROVIDER=anthropic  # defaults to LLM provider

# Optional: Override default models
export CODICIL_LLM_MODEL=claude-3-5-sonnet-20241022
export CODICIL_EMBEDDING_MODEL=voyage-3
```

### Usage

#### Enable the compiler tracer

In your project's `config/dev.exs` or at compile time:

```elixir
Code.put_compiler_option(:tracers, [Codicil.Tracer])
```

#### Start the MCP server

Add to your `mix.exs`:

```elixir
def project do
  [
    # ...
    aliases: aliases()
  ]
end

defp aliases do
  [
    codicil: "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Codicil.Plug, port: 4000) end)'"
  ]
end
```

Then run:

```bash
mix codicil
```

The MCP server will start on `http://localhost:4000/codicil/mcp` and wait for requests from your AI assistant.

#### Compile your project

```bash
mix compile
```

Codicil will automatically:
- Index all modules and functions
- Generate summaries (async, rate-limited)
- Create vector embeddings
- Build the call graph

#### Use with AI assistants

Configure your AI assistant to connect to the MCP server. The available tools are:

- **similar_functions** - `{"description": "find functions that validate email addresses"}`
- **function_callers** - `{"moduleName": "Elixir.MyApp.User", "functionName": "create", "arity": 1}`
- **function_callees** - `{"moduleName": "Elixir.MyApp.Orders", "functionName": "process", "arity": 1}`
- **module_relationships** - `{"moduleName": "Elixir.MyApp.Accounts"}`

### Development

```bash
# Install dependencies
mix deps.get

# Create database
mix ecto.create -r Codicil.Db.Repo

# Run migrations
mix ecto.migrate -r Codicil.Db.Repo

# Run tests
mix test

# Format code
mix format
```

### Database Schema

Codicil uses SQLite with the following tables:

- **functions** - Function definitions with summaries and embeddings
- **modules** - Module definitions
- **function_calls** - Call graph edges
- **module_dependencies** - Import/alias/use relationships

Vector search is powered by the `sqlite-vec` extension.

## Documentation

Full documentation is available at:
- **HexDocs**: https://hexdocs.pm/codicil
- **MCP Protocol Spec**: https://spec.modelcontextprotocol.io

## Contributing

Contributions welcome! Please:
1. Write tests first (TDD)
2. Follow the Router Pattern for GenServers (see CLAUDE.md)
3. Use atomic commits
4. Run `mix format` before committing

See `CLAUDE.md` for detailed development guidelines.

## License

MIT License - see LICENSE file for details.

## Status

**Functionally complete!** All core features are implemented and working:
- ✅ MCP server with 4 tools
- ✅ Compiler tracer for automatic indexing
- ✅ Multi-LLM support (5 providers)
- ✅ Vector embeddings with sqlite-vec
- ✅ Function call graph analysis
- ✅ Module dependency tracking

Remaining tasks:
- Generate real checksums for change detection
- Implement cleanup for deleted code
