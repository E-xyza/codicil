defmodule Codicil.Db.Function do
  @moduledoc """
  Schema for storing function metadata and embeddings.

  Functions are indexed from Elixir source files and include:
  - Basic metadata (name, path, line numbers)
  - AI-generated summary
  - Vector embedding for semantic search
  - Checksum for change detection
  """

  use Ecto.Schema

  schema "functions" do
    field(:name, :string)
    field(:module, :string)
    field(:arity, :integer)
    field(:exported, :boolean)
    field(:path, :string)
    field(:line, :integer)
    field(:parsed, :utc_datetime_usec)
    field(:docs, :string)
    field(:summary, :string)
    field(:embedding, :binary)
    field(:checksum, :string)
  end
end
