# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## IMPORTANT: Git Best Practices

When working in this repository, follow these git guidelines:

- **Feature branches**: Create a new branch for each feature or significant change (e.g., `git checkout -b feature/semantic-search`)
- **Commit messages**: Write clear, descriptive commit messages in imperative mood (e.g., "Add vector search tool", not "Added vector search tool")
- **Commit summaries**: Include a brief summary line (50 chars max), followed by a blank line and detailed description if needed
- **Logical commits**: Group related changes into single commits (e.g., all files for one tool in one commit, not mixing unrelated changes)
- **Atomic commits**: Each commit should represent a single, complete change that builds successfully

Example workflow:
```bash
git checkout -b feature/ast-parser
# Make changes...
git add lib/codicil/parser.ex test/codicil/parser_test.exs
git commit -m "Add Elixir AST parser for function extraction

- Parse def/defp/defmacro definitions
- Extract function signatures and line numbers
- Handle multi-clause functions
- Add comprehensive test coverage"
```

## Project Goal

**Codicil** is an Elixir-focused code analysis MCP (Model Context Protocol) server that provides semantic code search and structural analysis for Elixir codebases.

**Key Features:**
- Semantic function search using vector embeddings and LLM validation
- Module relationship tracking (imports, aliases, uses, requires)
- Function call graph analysis
- Natural language queries about codebase structure
- Integration with AI coding assistants via MCP protocol

**Note:** The `tidewave_phoenix/` and `graphsense/` directories contain temporary reference implementations that will be removed. Use them as examples for MCP server architecture and semantic search patterns, but build new code in the main project (`lib/codicil/`).

## Development Commands

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run a specific test file
mix test test/codicil_test.exs

# Run a specific test by line number
mix test test/codicil_test.exs:42

# Format code
mix format
```

## Usage

Codicil is designed to be used as a dependency in any Elixir project (following Tidewave's non-Phoenix pattern).

Add to your project's `mix.exs`:
```elixir
def deps do
  [
    {:codicil, "~> 0.1", only: :dev},
    {:bandit, "~> 1.6", only: :dev}
  ]
end
```

Add a Mix alias to start the MCP server:
```elixir
aliases: [
  codicil: "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Codicil.MCP.Server, port: 4000) end)'"
]
```

Then run `mix codicil` in your project to start the MCP server.

## Architecture

### MCP Server (inspired by Tidewave Phoenix)

**Note**: This is a library for non-Phoenix applications (following Tidewave's non-Phoenix pattern). Users add it as a dev dependency and start the MCP server via Bandit + Plug.

**Core Components:**
- `lib/codicil/mcp/server.ex` - Plug that handles JSON-RPC 2.0 messages and tool dispatch
- `lib/codicil/mcp.ex` - Supervisor managing MCP infrastructure
- `lib/codicil/application.ex` - Application entry point

**Tool System:**
Tools defined in `lib/codicil/mcp/tools/` with standard callback pattern:
- Return `{:ok, result}` or `{:error, reason}`
- Stateful tools use arity-2 callbacks (args, assigns)
- Stateless tools use arity-1 callbacks (args)
- Store callbacks in ETS for fast dispatch

**MCP Tools to Implement:**
- `similar_functions` - Semantic search for Elixir functions
- `function_callers` - Find functions that call a target
- `function_callees` - Find functions called by source
- `module_relationships` - Analyze import/alias/use chains

### Code Analysis Pipeline (inspired by GraphSense)

**Indexing Flow:**
1. Parse `.ex`/`.exs` files using `Code.string_to_quoted/2`
2. Extract function definitions, module docs, and relationships
3. Generate summaries using LLM (Claude 3.5 Sonnet)
4. Create vector embeddings (Pinecone or pgvector)
5. Store in dual databases (graph + vector)

**Database Strategy:**
- Single SQLite database with dual capabilities:
  - Graph tables: Module and function nodes, relationship edges (using CTEs for traversal)
  - Vector tables: Function embeddings via sqlite-vec extension
- Hybrid queries: Vector similarity + graph traversal + LLM reranking

**Elixir-Specific Features:**
- Parse AST to extract module attributes (`@moduledoc`, `@doc`, `@callback`)
- Track `import`, `alias`, `use`, `require` directives
- Handle protocols, behaviours, macros
- Support umbrella apps and Mix dependencies

## Key Implementation Patterns

### MCP Protocol (from reference: tidewave_phoenix)
- Tools use `inputSchema` following JSON Schema spec
- Register tool callbacks in ETS table for O(1) dispatch
- Supervisor tree: `Application → MCP Supervisor → [Registry, Logger, Tools]`
- Safe code execution: spawn_monitor with timeout and demonitor
- JSON-RPC 2.0 strict compliance for AI assistant compatibility

### Semantic Search (from reference: graphsense)
- **Batch LLM validation**: Process 20 functions at a time to reduce API costs
- **Early stopping**: Stop on first non-match (assumes similarity-sorted results degrade)
- **Hybrid ranking**: Vector similarity (fast) → Graph filtering (precise) → LLM reranking (accurate)
- **Per-repo isolation**: Separate database instances per analyzed codebase
- **Incremental indexing**: File watcher triggers re-analysis on changes

### Elixir Specifics
- Use `Code.string_to_quoted/2` with `:columns` option for position tracking
- Extract docs with `Code.fetch_docs/1` for compiled modules
- Pattern match AST for `def`, `defp`, `defmacro`, module directives
- Handle multi-clause functions (collect all clauses as single entity)
- Resolve aliases using `Macro.expand/2` for accurate relationship tracking

## Testing Strategy

- **Mirror structure**: `test/codicil/mcp/tools/search_test.exs` tests `lib/codicil/mcp/tools/search.ex`
- **MCP compliance**: Integration tests for JSON-RPC 2.0 protocol conformance
- **Mock databases**: Use in-memory fixtures instead of real Neo4j/PostgreSQL in tests
- **AST parsing**: Test with various Elixir syntax patterns (macros, protocols, guards)
- **Tool isolation**: Each tool test should be independent and fast

## Technical Requirements

- **Elixir**: 1.18+ (OTP 27+)
- **Mix project** with proper `mix.exs` configuration
- **Bandit**: `~> 1.6` (user's project provides this as dev dependency)
- **Git repository** required (for file change tracking)
- **Database**:
  - SQLite with sqlite-vec extension for vector search
  - Graph queries via Common Table Expressions (CTEs) in SQLite
  - Recommend `exqlite` or `ecto_sqlite3` for Elixir integration
- **API keys**:
  - Anthropic API key for Claude 3.5 Sonnet (summarization and embeddings)
  - Optional: Pinecone API key (if using external embeddings service)

**No Phoenix required** - This is a library dependency that users add to their Elixir projects.

## Configuration

Application config should support:
- `:root` - Project root directory (defaults to `File.cwd!()`)
- `:project_name` - Auto-detect from Mix.Project
- `:database` - Database connection settings
- `:llm_provider` - LLM configuration for summarization
- `:embedding_provider` - Vector embedding service config
