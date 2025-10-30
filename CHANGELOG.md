# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
