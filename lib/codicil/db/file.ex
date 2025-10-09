defmodule Codicil.Db.File do
  @moduledoc """
  Schema for storing file metadata.

  Files represent source files in the indexed codebase.
  """

  use Ecto.Schema

  schema "files" do
    field(:path, :string)
    field(:checksum, :string)
    field(:parsed, :utc_datetime_usec)
  end
end
