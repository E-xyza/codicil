# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `list_module_dependents` MCP tool - reverse dependency lookup to find all modules that depend on a given module
  - Supports filtering by dependency type (`compiler` or `runtime`)
  - Useful for assessing impact before refactoring or deprecating a module

## [0.6.0] - 2025-01-09

### Added

- Support for overriding MCP tool descriptions at compile time via application configuration
  - Example: `config :codicil, Codicil.MCP.Tools.FindSimilarFunctions, "custom description"`

## [0.5.0] - 2025-11-03

### Removed

- **BREAKING**: Removed `get_module_file_path` MCP tool as it duplicates functionality available in Tidewave
- Reduced tool count from 6 to 5 tools to minimize overlap between MCP servers

## [0.4.0] - 2025-11-03

### Changed

- **BREAKING**: Renamed all MCP tools for better discoverability and consistency:
  - `similar_functions` → `find_similar_functions`
  - `function_callers` → `list_function_callers`
  - `function_callees` → `list_function_callees`
  - `module_relationships` → `list_module_dependencies`
  - `module_file` → `get_module_file_path`
  - `function_code` → `get_function_source_code`

### Improved

- Enhanced all MCP tool descriptions with:
  - Clear use cases and trigger phrases for better AI assistant tool selection
  - Explicit debugging and refactoring contexts for callers/callees tools
  - Important notes to use indexed tools instead of shell commands (`ls`, `grep`)
  - More action-oriented naming (find/list/get prefixes)

### Fixed

- Multi-clause functions now correctly capture all clauses in the `code` field
- Added comprehensive test coverage for multi-clause function extraction
- Fixed RateLimiter error handling in tests when GenServer is not running

## [0.3.0] - 2025-11-01

### Added

- `mix codicil.migrate` task for running database migrations
- `module_file` MCP tool to get the file path where a module is defined
- `function_code` MCP tool to retrieve function source code with preceding module-level use/alias/import directives
- Documentation for combining multiple MCP servers (Codicil + Tidewave) in README and module docs

## [0.2.1] - 2025-10-30

### Fixed

- Fix tracer crash when compiling files with top-level defimpl statements

## [0.2.0] - 2025-10-30

### Added

- `mix codicil.setup` task for easy database initialization (creates database and runs migrations)

### Changed

- **BREAKING**: The `exported` field in the `functions` table is now required (NOT NULL constraint added)
- Updated `Function` changeset to require the `exported` field at validation level
- Placeholder functions (for external dependencies) now always have `exported: true` by default

### Improved

- Tracer now provides clear error messages when `CODICIL_LLM_PROVIDER` is not set
- Better startup error handling to prevent silent compilation failures

## [0.1.0] - 2025-01-08

### Added

Initial release of Codicil - semantic code search and analysis for Elixir projects via MCP.

**MCP Tools:**

- `similar_functions` - Semantic search for functions by behavior description
- `function_callers` - Find all functions that call a specific function
- `function_callees` - Find all functions called by a specific function
- `module_relationships` - Analyze module dependency chains (imports, aliases, uses, requires)
