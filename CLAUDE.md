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

## IMPORTANT: Test-Driven Development (TDD) Workflow

**CRITICAL:** From this point forward, all development MUST follow strict Test-Driven Development (TDD):

### Microfeature Development Cycle

1. **Write the test FIRST**
   - Identify a small, focused microfeature to implement
   - Write a failing test that describes the expected behavior
   - Run the test to confirm it fails (red)

2. **Make the test pass**
   - Implement the minimal code necessary to make the test pass
   - Run the test to confirm it passes (green)
   - Refactor if needed while keeping tests green

3. **Commit immediately**
   - Commit both the test and implementation together
   - Each commit should contain ONE microfeature (test + code)
   - Never commit code without its corresponding test
   - Never commit multiple microfeatures in a single commit

### What is a Microfeature?

A microfeature is a small, atomic piece of functionality that:
- Can be tested independently
- Takes minutes, not hours, to implement
- Has a clear, single responsibility
- Represents one behavior or capability

### Examples of Microfeatures

**Good microfeatures (one commit each):**
- "Add Function schema with basic fields"
- "Add function name validation to changeset"
- "Add database connection configuration"
- "Add query to find function by name and path"
- "Add index on functions (name, path) columns"

**Too large (should be split):**
- ❌ "Add complete database layer" (split into schema, repo, migrations, queries)
- ❌ "Implement AST parser" (split into parse file, extract functions, detect calls, etc.)

### TDD Workflow Example

```bash
# 1. Write failing test
# Create test/codicil_db/function_test.exs
mix test  # Confirm it fails (RED)

# 2. Implement minimal code to pass
# Create lib/codicil_db/function.ex with schema
mix test  # Confirm it passes (GREEN)

# 3. Commit immediately
git add test/codicil_db/function_test.exs lib/codicil_db/function.ex
git commit -m "Add Function schema with basic fields

- Define Ecto schema for functions table
- Include id, name, path, start_line, end_line fields
- Add test verifying schema struct creation"

# 4. Repeat for next microfeature
```

### Why This Matters

- **Prevents scope creep**: Forces you to think in small increments
- **Better git history**: Each commit is self-contained and understandable
- **Easier debugging**: Small commits make it easy to identify when bugs were introduced
- **Confidence**: Every commit has passing tests, so main branch is always working
- **Reviewability**: Small, focused commits are easier to review and understand

### Red-Green-Refactor Discipline

1. **RED**: Write a failing test
2. **GREEN**: Make it pass with minimal code
3. **REFACTOR**: Clean up while keeping tests green
4. **COMMIT**: Save your work

Never skip the RED step - always verify your test fails before implementing!

## Project Goal

**Codicil** is an Elixir-focused code analysis MCP (Model Context Protocol) server that provides semantic code search and structural analysis for Elixir codebases.

**Key Features:**
- Semantic function search using vector embeddings and LLM validation
- Module relationship tracking (imports, aliases, uses, requires)
- Function call graph analysis
- Natural language queries about codebase structure
- Integration with AI coding assistants via MCP protocol

**Note:** The `graphsense/` directory contains a temporary TypeScript reference implementation that will be removed once the Elixir equivalent is complete. Use it as an example for semantic search patterns, but build new code in the main project (`lib/codicil/`).

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

## IMPORTANT: Library Configuration and Migrations

**This is a library, NOT an application - special rules apply:**

### Config Files (DO NOT CREATE)
- **NEVER** create `config/config.exs` or any config files in this project
- Libraries should not have runtime configuration files checked into source control
- Users configure Codicil in their own application's config
- If runtime configuration is needed, use application environment: `Application.get_env(:codicil, :key)`

### Running Migrations
- **ALWAYS** use the `-r` flag to specify the repo when running migrations
- Standard commands work with the repo flag:

```bash
# Drop database
mix ecto.drop -r Codicil.Db.Repo

# Create database
mix ecto.create -r Codicil.Db.Repo

# Run migrations
mix ecto.migrate -r Codicil.Db.Repo

# Rollback migrations
mix ecto.rollback -r Codicil.Db.Repo

# Reset database (drop, create, migrate)
# Note: mix ecto.reset does not exist, chain commands instead:
mix ecto.drop -r Codicil.Db.Repo && mix ecto.create -r Codicil.Db.Repo && mix ecto.migrate -r Codicil.Db.Repo
```

### Testing with Database
- Tests handle Repo startup in `test/test_helper.exs`
- Use `Ecto.Adapters.SQL.Sandbox` for test isolation
- Each test gets its own transaction that rolls back automatically
- Migrations run automatically in test setup

## Usage

Codicil is designed to be used as a dependency in any Elixir project.

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
  codicil: "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Codicil.Plug, port: 4000) end)'"
]
```

Then run `mix codicil` in your project to start the MCP server.

## Architecture

### MCP Server (Core Infrastructure - ✅ Complete)

**Note**: This is a library for non-Phoenix applications. Users add it as a dev dependency and start the MCP server via Bandit + Plug.

**Core Components:**
- `lib/codicil/mcp/server.ex` - Plug that handles JSON-RPC 2.0 messages and tool dispatch
- `lib/codicil/mcp.ex` - Supervisor managing MCP infrastructure
- `lib/codicil/application.ex` - Application entry point
- `lib/codicil/plug.ex` - HTTP transport adapter

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

### Code Analysis Pipeline

**Indexing Flow (Using Compiler Tracers):**
1. Hook into Elixir's compilation process via `Code.put_compiler_option(:tracers, [Codicil.Tracer])`
2. Receive compilation events in `Codicil.Tracer.trace/2` callback
3. Capture module/function relationships and metadata during compilation
4. Extract full function info post-compilation using `Code.fetch_docs/1`
5. Generate summaries using LLM (Claude 3.5 Sonnet)
6. Create vector embeddings (Anthropic or local)
7. Store in SQLite database with graph and vector capabilities

**Database Strategy:**
- Single SQLite database with dual capabilities:
  - Graph tables: Module and Function tables, relationship edges (using CTEs for traversal)
  - Vector tables: Function embeddings via sqlite-vec extension
- Hybrid queries: Vector similarity + graph traversal + LLM reranking

**Compiler Tracer Approach:**
Reference: https://hexdocs.pm/elixir/main/Code.html

**Tracer Implementation:**
- Create module with `trace/2` function: `trace(event, %Macro.Env{})`
- Must return `:ok` and do minimal synchronous work
- Dispatch bulk work to separate process to avoid slowing compilation

**Key Tracer Events:**
1. **Module Lifecycle:**
   - `:start` - Compiler begins tracing new lexical context
   - `:stop` - Compiler stops tracing lexical context
   - `:defmodule` - Module definition starts

2. **Import/Alias/Require:**
   - `{:import, meta, module, opts}` - Track imports
   - `{:alias, meta, alias, as, opts}` - Track aliases
   - `{:require, meta, module, opts}` - Track requires

3. **Function References:**
   - `{:remote_function, meta, module, name, arity}` - External calls
   - `{:local_function, meta, name, arity}` - Local calls
   - `{:imported_function, meta, module, name, arity}` - Imported calls

4. **Module Compilation:**
   - `{:on_module, bytecode, _}` - Module fully defined, extract all info here

**Post-Compilation Extraction:**
- Use `Code.fetch_docs/1` for function documentation and signatures
- Use `Module.__info__(:functions)` and `Module.__info__(:macros)` for function lists
- Combine tracer events with post-compilation introspection for complete picture
- No AST parsing needed - all info available from compiler and runtime

## GraphSense Transfer Strategy

The `graphsense/` directory contains a TypeScript/Node.js reference implementation. We need to port its semantic search patterns to Elixir.

### Phase 1: Database Layer (Priority: High)

**Files to create:**
- `lib/codicil_db/repo.ex` - Ecto repository (Codicil.Db.Repo)
- `lib/codicil_db/function.ex` - Function schema (Codicil.Db.Function)
- `lib/codicil_db/edge.ex` - Relationship edge schema (Codicil.Db.Edge)
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_functions.exs` - Functions table
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_edges.exs` - Edges table
- `priv/repo/migrations/YYYYMMDDHHMMSS_add_indices.exs` - Indices for performance

**Patterns from GraphSense:**
- Dual-database approach (Neo4j → SQLite graph tables, PostgreSQL+pgvector → SQLite+sqlite-vec)
- Database per repository (isolation via path-based DB files)
- Schema: `functions` table with id, name, path, start_line, end_line, summary, embedding, checksum
- Graph constraints: unique (name, path) for functions, unique path for files

**Key Changes:**
- Replace Neo4j with SQLite graph tables using CTEs for traversal
- Replace PostgreSQL+pgvector with SQLite+sqlite-vec
- Use Elixir's `:ecto_sql` with `:ecto_sqlite3` adapter
- Store relationships as edges table: `edges(from_id, to_id, type)` where type = 'CALLS' | 'IMPORTS_FROM'

### Phase 2: AST Parser (Priority: High)

**Files to create:**
- `lib/codicil/parser.ex` - Main Elixir AST parser
- `lib/codicil/parser/function.ex` - Function extraction and analysis
- `lib/codicil/parser/module.ex` - Module relationship tracking
- `lib/codicil/parser/calls.ex` - Function call detection

**Patterns from GraphSense (TypeScript AST):**
- Parse file → extract imports → extract functions → build call graph
- Queue-based processing with rate limiting (avoid API throttling)
- Checksum-based change detection (don't re-process unchanged functions)
- Extract function metadata: name, path, start_line, end_line, full text

**Elixir-Specific Adaptations:**
- Use `Code.string_to_quoted/2` with `columns: true` for position tracking
- Pattern match on `{:def, _, _}`, `{:defp, _, _}`, `{:defmacro, _, _}`
- Handle multi-clause functions (collect all clauses as single entity)
- Track module attributes: `{:@, _, [{:moduledoc, _, _}]}`, `{:@, _, [{:doc, _, _}]}`
- Extract relationships: `{:import, _, _}`, `{:alias, _, _}`, `{:use, _, _}`, `{:require, _, _}`
- Detect function calls by traversing AST for `{name, _, args}` nodes where name is atom

### Phase 3: LLM Integration (Priority: Medium)

**Files to create:**
- `lib/codicil/llm.ex` - LLM client abstraction
- `lib/codicil/llm/anthropic.ex` - Claude API integration
- `lib/codicil/llm/summarizer.ex` - Function summary generation
- `lib/codicil/llm/validator.ex` - Batch function validation

**Patterns from GraphSense:**
- Generate function summaries: `generateText(model, prompt: "Given the following function body, generate a summary: ...")`
- Batch validation: Process 20 functions at a time with structured output
- Early stopping: Stop on first non-match (assumes similarity-sorted results degrade)
- Retry logic: 3 attempts with exponential backoff (1s → 2.5s → 6.25s)
- Schema validation: Use structured output for batch evaluations

**Elixir Adaptations:**
- Use `req` HTTP client for Anthropic API calls
- Implement GenServer for rate-limited LLM queue processing
- Use `Jason` for JSON encoding/decoding
- Structured output via JSON schema in prompt + validation

### Phase 4: Vector Embeddings (Priority: Medium)

**Files to create:**
- `lib/codicil/embeddings.ex` - Embedding client abstraction
- `lib/codicil/embeddings/anthropic.ex` - Claude embeddings (if available)
- `lib/codicil/embeddings/local.ex` - Local embedding model fallback

**Patterns from GraphSense:**
- Pinecone embeddings: `pinecone.inference.embed("multilingual-e5-large", [text], {inputType: "passage|query"})`
- Vector dimension: 1024 (multilingual-e5-large)
- Separate input types: "passage" for indexing, "query" for searching
- Store as VECTOR(1024) in PostgreSQL pgvector → SQLite sqlite-vec

**Elixir Adaptations:**
- Use Anthropic API for embeddings (if available) or local model
- Store embeddings as binary blobs or JSON arrays in SQLite
- Use `sqlite-vec` extension for vector similarity search: `SELECT * FROM functions ORDER BY embedding <=> $1 LIMIT 20`

### Phase 5: MCP Tools (Priority: High)

**Files to create:**
- `lib/codicil/mcp/tools/similar_functions.ex` - Semantic function search
- `lib/codicil/mcp/tools/function_callers.ex` - Find callers via graph
- `lib/codicil/mcp/tools/function_callees.ex` - Find callees via graph
- `lib/codicil/mcp/tools/module_relationships.ex` - Import/alias tracking

**Patterns from GraphSense MCP Tools:**

**similar_functions:**
```typescript
// 1. Generate embedding for query
embedding = await pinecone.inference.embed("multilingual-e5-large", [description])

// 2. Vector similarity search (no limit)
results = await db.query(`
  SELECT id, summary, path, name, start_line, end_line,
         1 - (embedding <=> $1::vector) as similarity_score
  FROM functions
  WHERE embedding IS NOT NULL AND summary IS NOT NULL
  ORDER BY embedding <=> $1::vector
`, [embedding])

// 3. Batch LLM validation (20 at a time)
validatedFunctions = await batchValidateFunctions(description, results, batchSize=20)

// 4. Return formatted results
```

**function_callers:**
```cypher
MATCH (caller:Function)-[:CALLS]->(target:Function)
WHERE target.name = $functionName AND target.path = $functionPath
RETURN caller.name, caller.path, caller.summary
```

**function_callees:**
```cypher
MATCH (source:Function)-[:CALLS]->(callee:Function)
WHERE source.name = $functionName AND source.path = $functionPath
RETURN callee.name, callee.path, callee.summary
```

**Elixir Adaptations:**
- Replace Cypher with SQLite CTEs or joins on edges table
- Use Ecto queries for type safety and composability
- Return results as `{:ok, text}` or `{:ok, %{content: [%{type: "text", text: ...}]}}`

### Phase 6: Indexing & Watcher (Priority: Low)

**Files to create:**
- `lib/codicil/indexer.ex` - Main indexing coordinator
- `lib/codicil/watcher.ex` - File system watcher for incremental updates

**Patterns from GraphSense:**
- Glob files: `**/*.{ex,exs}` excluding `deps/`, `_build/`, `.git/`
- Process queue with rate limiting (1 second delay between LLM calls)
- Checksum-based change detection
- File watcher for real-time re-indexing

## Key Implementation Patterns

### MCP Protocol
- Tools use `inputSchema` following JSON Schema spec
- Register tool callbacks in ETS table for O(1) dispatch
- Supervisor tree: `Application → MCP Supervisor → [Registry, Logger, Tools]`
- Safe code execution: spawn_monitor with timeout and demonitor
- JSON-RPC 2.0 strict compliance for AI assistant compatibility

### Semantic Search (from GraphSense)
- **Batch LLM validation**: Process 20 functions at a time to reduce API costs
- **Early stopping**: Stop on first non-match (assumes similarity-sorted results degrade)
- **Hybrid ranking**: Vector similarity (fast) → Graph filtering (precise) → LLM reranking (accurate)
- **Per-repo isolation**: Separate database instances per analyzed codebase
- **Incremental indexing**: File watcher triggers re-analysis on changes
- **Rate limiting**: 1 second delay between LLM API calls to avoid throttling
- **Retry logic**: Exponential backoff (3 attempts: 1s, 2.5s, 6.25s)

### Elixir Specifics
- Use `Code.string_to_quoted/2` with `:columns` option for position tracking
- Extract docs with `Code.fetch_docs/1` for compiled modules
- Pattern match AST for `def`, `defp`, `defmacro`, module directives
- Handle multi-clause functions (collect all clauses as single entity)
- Resolve aliases using `Macro.expand/2` for accurate relationship tracking

### Router Pattern for GenServers

**IMPORTANT:** All GenServers and GenServer-like modules (LiveViews, etc.) should follow the Router Pattern for code organization.

The Router Pattern organizes GenServer code into clear sections that make it easy to understand the API and find implementations:

#### Structure

```elixir
defmodule MyGenServer do
  use GenServer

  # 1. BOILERPLATE & INITIALIZATION
  # - child_spec, start_link, init
  # - These rarely change once written

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.id))
  end

  def init(args) do
    {:ok, %{id: args.id, data: nil}}
  end

  # 2. API (Public interface - what external callers use)
  # - Declare @spec for all public functions
  # - Keep implementations one-liners that delegate to handle_* via GenServer.call/cast

  @spec get_data(id :: term()) :: term()
  def get_data(id) do
    GenServer.call(via_tuple(id), :get_data)
  end

  @spec set_data(id :: term(), data :: term()) :: :ok
  def set_data(id, data) do
    GenServer.cast(via_tuple(id), {:set_data, data})
  end

  # 3. API IMPLEMENTATION (Private - the actual logic)
  # - defp functions that contain the real implementation
  # - For handle_call: defp name_impl(args..., from, state)
  # - For handle_cast: defp name_impl(args..., state)  # NO 'from' parameter
  # - For handle_info: defp name_impl(message, state)
  # - Always return the full tuple {:reply, result, state} or {:noreply, state}

  defp get_data_impl(_from, state) do
    {:reply, state.data, state}
  end

  defp set_data_impl(data, state) do
    {:noreply, %{state | data: data}}
  end

  # 4. HELPER FUNCTIONS (if needed)
  # - Pure functions used by implementations
  # - Via tuples, formatters, etc.

  defp via_tuple(id) do
    {:via, Registry, {MyRegistry, id}}
  end

  # 5. ROUTER (Boilerplate at bottom - write once, never think about again)
  # - Simple pattern matching that routes to implementations
  # - One-to-one correspondence with API functions above
  # - For calls: Pass 'from' to implementation
  # - For casts: Do NOT pass 'from' to implementation

  def handle_call(:get_data, from, state) do
    get_data_impl(from, state)
  end

  def handle_cast({:set_data, data}, state) do
    set_data_impl(data, state)
  end
end
```

#### Key Rules

1. **API functions are one-liners** that call `GenServer.call/cast/info`
2. **Implementation functions (defp *_impl)** contain the actual logic
3. **For handle_call**: Implementation takes `(args..., from, state)`
4. **For handle_cast**: Implementation takes `(args..., state)` - NO 'from' parameter
5. **For handle_info**: Implementation takes `(message, state)`
6. **Router at bottom** is pure boilerplate - pattern match and delegate
7. **Always pass full GenServer return tuples** from implementations: `{:reply, ...}`, `{:noreply, ...}`, `{:stop, ...}`

#### Benefits

- **Locality**: API declaration, spec, and implementation are adjacent
- **Clarity**: Router is obvious mechanical translation, no logic hidden there
- **Testability**: Implementation functions are easily testable
- **Maintainability**: Each section has a clear purpose
- **Consistency**: Once you learn the pattern, all GenServers look the same

#### Anti-patterns to Avoid

- ❌ Putting logic inside `handle_call/cast/info` clauses
- ❌ Separating API functions from their implementations
- ❌ Passing `from` to cast implementations (casts don't have a 'from')
- ❌ Passing unnecessary state data that's already in state (like `state.module`)
- ❌ Making router anything other than pure pattern-match-and-delegate

## Database Guidelines

**IMPORTANT:** Follow these conventions when working with the database layer:

### Directory Structure
- **All database schemas** must be placed in `lib/codicil_db/`
- **Namespace**: All schemas use the `Codicil.Db` namespace
- **Example**: `lib/codicil_db/function.ex` → `defmodule Codicil.Db.Function`

### Code Style
- **DO NOT** use `import Ecto.Changeset`
- **DO** use `alias Ecto.Changeset` instead
- This ensures explicit changeset function calls for better code clarity
- **DO NOT** use multi-alias syntax: `alias A.{B, C}` (this is for IEx only)
- **DO** use separate alias statements: `alias A.B` and `alias A.C`
- This maintains consistency with standard Elixir code style
- **DO NOT** use `as:` in alias statements: `alias Foo.Bar, as: Baz`
- **DO** use the full module name directly in code instead
- Renaming modules obscures where things come from and makes code harder to search/navigate
- **ALWAYS** place all `alias` and `require` statements at the head of the module, immediately after `use` statements
- This follows Elixir convention and makes dependencies immediately visible
- **DO NOT** place `alias` statements inside function bodies or private function definitions

### Context Module Naming
- **DO NOT** use redundant names in context functions
- **Example**: Use `Function.create/1` NOT `Function.create_function/1`
- **Example**: Use `Function.get/1` NOT `Function.get_function/1`
- The module name already provides context, so function names should be concise

### Accessor Function Conventions
Follow Elixir standards for data retrieval functions:
- **`fetch/1`** - Returns `{:ok, data}` on success, `{:error, reason}` on failure (including not found)
- **`fetch!/1`** - Returns `data` on success, raises on failure (including not found)
- **`get/1`** - Returns `data` on success, `nil` if not found, crashes on database errors
- **Example**:
  - `Function.fetch("id-123")` → `{:ok, %Function{}}` or `{:error, :not_found}`
  - `Function.fetch!("id-123")` → `%Function{}` or raises
  - `Function.get("id-123")` → `%Function{}` or `nil`

### Parameter Conventions
- **ALWAYS use atom keys** for parameter maps/structs
- This codebase does not consume user-inputted data, so atom keys are safe and idiomatic
- **Example**: `%{name: "foo", path: "/lib/foo.ex"}` NOT `%{"name" => "foo", "path" => "/lib/foo.ex"}`

### Datetime Fields
- **ALWAYS** use `:utc_datetime_usec` type for all datetime fields in schemas
- **DO NOT** use `:naive_datetime` or `:utc_datetime` (millisecond precision)
- Microsecond precision ensures compatibility with Ecto timestamps and better accuracy
- Example: `field :parsed, :utc_datetime_usec`
- In tests, use `DateTime.utc_now()` to generate datetime values

### Database Location
- SQLite database file must be stored in Codicil's `priv/` directory
- Obtain the path using `:code.priv_dir(:codicil)`
- Example: `Path.join(:code.priv_dir(:codicil), "codicil.db")`

### Migration Strategy
- **Each table gets its own migration file**
- **Indices and foreign keys** MAY be in separate migrations (use judgement)
- **DO NOT create new migrations** to modify existing tables
- **DO** modify the original migration file if changes are needed
- This keeps migration history clean and deployment simple

### Example Structure
```
lib/codicil_db/
├── function.ex          # Codicil.Db.Function schema
├── edge.ex              # Codicil.Db.Edge schema
└── repo.ex              # Codicil.Db.Repo

priv/repo/migrations/
├── 20250101000001_create_functions.exs
├── 20250101000002_create_edges.exs
└── 20250101000003_add_function_indices.exs
```

## Testing Strategy

- **Mirror structure**: `test/codicil/mcp/tools/search_test.exs` tests `lib/codicil/mcp/tools/search.ex`
- **MCP compliance**: Integration tests for JSON-RPC 2.0 protocol conformance
- **Mock databases**: Use in-memory SQLite for tests (`:memory:` database)
- **AST parsing**: Test with various Elixir syntax patterns (macros, protocols, guards)
- **Tool isolation**: Each tool test should be independent and fast
- **Property testing**: Use StreamData for AST edge cases
- **Async tests**: ALWAYS use `async: true` in test modules for parallel execution
  - Example: `use ExUnit.Case, async: true`
  - SQLite with sandbox mode supports concurrent tests
- **Boolean assertions**: Use idiomatic ExUnit assertions for boolean values
  - **DO**: `assert value` instead of `assert value == true`
  - **DO**: `refute value` instead of `assert value == false`
  - This makes tests more readable and follows Elixir conventions
- **Don't test framework behavior**: Do NOT write tests that just verify Ecto schemas work
  - **DON'T**: Test that schema fields exist or that basic CRUD operations work
  - **DO**: Test business logic, validations, custom behavior, and edge cases
  - **Example of bad test**: `test "schema has id field" do assert Map.has_key?(%Schema{}, :id) end`
  - **Example of good test**: `test "validates email format" do assert {:error, _} = create(%{email: "invalid"}) end`

## Technical Requirements

- **Elixir**: 1.18+ (OTP 27+)
- **Mix project** with proper `mix.exs` configuration
- **Bandit**: `~> 1.6` (user's project provides this as dev dependency)
- **Git repository** required (for file change tracking)
- **Database**:
  - SQLite with `sqlite-vec` extension for vector search
  - Ecto with `:ecto_sqlite3` adapter
  - Graph queries via Common Table Expressions (CTEs)
  - Schema: functions table + edges table for relationships
- **API keys**:
  - Anthropic API key for Claude 3.5 Sonnet (summarization and embeddings)
- **Dependencies to add**:
  - `:ecto_sql` - Database abstraction
  - `:ecto_sqlite3` - SQLite adapter
  - `:exqlite` - Native SQLite driver (required by ecto_sqlite3)
  - `:req` - HTTP client for API calls
  - `:jason` - JSON encoding/decoding (already added)

**No Phoenix required** - This is a library dependency that users add to their Elixir projects.

## Configuration

Application config should support:
- `:root` - Project root directory (defaults to `File.cwd!()`)
- `:project_name` - Auto-detect from Mix.Project
- `:database_path` - SQLite database file path (defaults to `:code.priv_dir(:codicil)/codicil.db`)
- `:anthropic_api_key` - Claude API key (defaults to `System.get_env("ANTHROPIC_API_KEY")`)
- `:batch_size` - LLM validation batch size (defaults to 20)
- `:rate_limit_ms` - Delay between LLM calls (defaults to 1000ms)

## Implementation Order

1. **✅ Phase 0: MCP Core** (Complete)
   - Server, supervisor, utilities, Plug adapter
   - Test suite passing

2. **✅ Phase 1: Database Layer** (Complete)
   - SQLite setup with Ecto
   - Schema migrations (functions, modules, module_dependencies, function_calls tables)
   - Graph query helpers via Ecto
   - Context modules (Functions, Modules)

3. **✅ Phase 2: Compiler Tracer** (Complete - Better than AST Parser!)
   - Compiler tracer hooks via `Code.put_compiler_option(:tracers, [Codicil.Tracer])`
   - ModuleTracer GenServer tracks individual module compilation
   - Extract functions, modules, relationships during compilation
   - Build call graph from bytecode analysis
   - Parse source for line numbers and docs

4. **🚧 Phase 3: LLM Integration** (Partial)
   - ✅ LLM protocol using Protoss
   - ✅ Claude, OpenAI, Grok clients
   - ❌ Function summarizer (needed for semantic search)
   - ❌ Batch validator (needed for semantic search)

5. **❌ Phase 4: Vector Embeddings** (Not Started)
   - Embedding generation (Anthropic or local)
   - Vector storage in SQLite
   - sqlite-vec extension integration

6. **🚧 Phase 5: MCP Tools** (Partial)
   - ❌ `similar_functions` tool (PRIORITY - needs Phase 4 & 3 completion)
   - ✅ `function_callers` tool
   - ✅ `function_callees` tool
   - ✅ `module_relationships` tool

7. **❌ Phase 6: Indexing & Watcher** (Not Started)
   - Repository indexing coordinator
   - File watching for incremental updates
