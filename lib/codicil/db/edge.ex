defmodule Codicil.Db.Edge do
  @moduledoc """
  Schema for storing relationships between functions.

  Edges represent different types of relationships:
  - :calls - Function A calls Function B
  - :imports_from - Module A imports from Module B
  """

  use Ecto.Schema
  import EctoEnum

  defenum(EdgeType, calls: 0, imports_from: 1)

  schema "edges" do
    field(:from_id, :integer)
    field(:to_id, :integer)
    field(:type, EdgeType)
  end
end
