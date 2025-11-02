defmodule Codicil.Functions do
  # Context module for managing function records in the database.
  @moduledoc false

  alias Codicil.Db.Function
  alias Codicil.Db.Repo

  @doc """
  Creates a new function record.
  """
  def create(attrs) do
    %Function{}
    |> Function.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates or updates a function record.
  Uses upsert based on unique constraint (module, name, arity).
  Skips database write if checksum matches existing record.

  Returns:
  - `{:ok, function}` - Function was created or updated
  - `{:same, function}` - Function already exists with same checksum (no write)
  - `{:error, changeset}` - Validation failed
  """
  def upsert(%{module: module, name: name, arity: arity, checksum: checksum} = attrs) do
    # Convert string keys to atoms for get_by_mfa lookup
    module_atom = if is_binary(module), do: String.to_atom(module), else: module
    name_atom = if is_binary(name), do: String.to_atom(name), else: name

    case get_by_mfa({module_atom, name_atom, arity}) do
      %Function{checksum: ^checksum, marked_for_deletion: false} = function ->
        # Function exists with same checksum and not marked - no update needed
        {:same, function}

      _ ->
        # Function doesn't exist, checksum changed, or marked for deletion - upsert it
        # Only set parsed timestamp if not explicitly provided (e.g., placeholders set parsed: nil)
        attrs_with_parsed =
          if Map.has_key?(attrs, :parsed_at) do
            attrs
          else
            Map.put(attrs, :parsed_at, DateTime.utc_now())
          end

        attrs_with_parsed
        |> Function.changeset()
        |> Repo.insert(
          on_conflict: {:replace_all_except, [:id, :parsed_at]},
          conflict_target: [:module, :name, :arity],
          returning: true
        )
    end
  end

  @doc """
  Creates a placeholder function record for a function that hasn't been compiled yet.
  Leaves parsed: nil to indicate it's a placeholder.
  Uses placeholder values for required fields.
  Returns {:ok, function} tuple matching the pattern expected by callers.
  """
  def create_placeholder({module, name, arity}) do
    # Convert atoms to strings for database storage
    module_str = if is_atom(module), do: Atom.to_string(module), else: module
    name_str = if is_atom(name), do: Atom.to_string(name), else: name

    # Convert back to atoms for lookup
    module_atom = if is_binary(module_str), do: String.to_atom(module_str), else: module_str
    name_atom = if is_binary(name_str), do: String.to_atom(name_str), else: name_str

    # Check if function already exists
    case get_by_mfa({module_atom, name_atom, arity}) do
      nil ->
        # Create new placeholder
        attrs = %{
          module: module_str,
          name: name_str,
          arity: arity,
          exported: true,
          checksum: nil,
          parsed: nil
        }

        attrs
        |> Function.changeset()
        |> Repo.insert()

      existing ->
        # Return existing function (could be placeholder or real function)
        {:ok, existing}
    end
  end

  @doc """
  Lists all functions.
  Returns a list of function structs.
  """
  def list do
    Repo.all(Function)
  end

  @doc """
  Lists functions that need processing (summarization or embedding).

  Returns functions where:
  - Exported functions without summary OR embedding
  - Functions with docs but without summary OR embedding
  - Not marked for deletion
  """
  def list_incomplete do
    import Ecto.Query

    from(f in Function,
      where: f.marked_for_deletion == false,
      where:
        (f.exported == true and (is_nil(f.summary) or is_nil(f.embedding))) or
          (not is_nil(f.docs) and f.docs != "" and
             (is_nil(f.summary) or is_nil(f.embedding)))
    )
    |> Repo.all()
  end

  @doc """
  Retrieves a function by ID.
  Returns the function struct or nil if not found.
  """
  def get(id) do
    Repo.get(Function, id)
  end

  @doc """
  Retrieves a function by module, function name, and arity (MFA tuple).
  Returns the function struct or nil if not found.
  """
  def get_by_mfa({module, name, arity})
      when is_atom(module) and is_atom(name) and is_integer(arity) do
    import Ecto.Query

    module_str = Atom.to_string(module)
    name_str = Atom.to_string(name)

    from(f in Function,
      where: f.module == ^module_str and f.name == ^name_str and f.arity == ^arity,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Updates a function record.
  """
  def update(%Function{} = function, attrs) do
    function
    |> Function.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a function record.
  """
  def delete(%Function{} = function) do
    Repo.delete(function)
  end

  @doc """
  Creates a function call relationship between a caller and a callee.
  Uses a butterfly table (many-to-many without schema).
  Returns :ok on success, preventing duplicate relationships.
  """
  def add_call(%Function{id: caller_id}, %Function{id: callee_id}) do
    import Ecto.Query

    # Check if relationship already exists
    existing =
      from(fc in "function_calls",
        where: fc.caller_id == ^caller_id and fc.callee_id == ^callee_id,
        select: 1
      )
      |> Repo.one()

    if existing do
      :ok
    else
      # Insert new relationship
      Repo.insert_all("function_calls", [%{caller_id: caller_id, callee_id: callee_id}])
      :ok
    end
  end

  @doc """
  Lists all functions called by the given function.
  Returns a list of Function structs.
  """
  def list_calls(%Function{id: caller_id}) do
    import Ecto.Query

    from(f in Function,
      join: fc in "function_calls",
      on: fc.callee_id == f.id,
      where: fc.caller_id == ^caller_id
    )
    |> Repo.all()
  end

  @doc """
  Lists all functions that call the given function.
  Returns a list of Function structs.
  """
  def list_called_by(%Function{id: callee_id}) do
    import Ecto.Query

    from(f in Function,
      join: fc in "function_calls",
      on: fc.caller_id == f.id,
      where: fc.callee_id == ^callee_id
    )
    |> Repo.all()
  end

  @doc """
  Lists all functions belonging to a given module.
  Returns a list of Function structs.
  """
  def list_by_module(module) when is_atom(module) do
    import Ecto.Query

    module_str = Atom.to_string(module)

    from(f in Function,
      where: f.module == ^module_str
    )
    |> Repo.all()
  end

  @doc """
  Finds functions similar to a query vector using cosine distance.

  ## Parameters
  - `query_vector` - List of floats representing the query embedding
  - `opts` - Options:
    - `:limit` - Maximum number of results (default: 20)

  ## Returns
  - List of Function structs ordered by similarity (most similar first)

  ## Example
      iex> Functions.find_similar([0.1, 0.2, 0.3], limit: 10)
      [%Function{}, ...]
  """
  def find_similar(query_vector, opts \\ []) when is_list(query_vector) do
    limit = Keyword.get(opts, :limit, 20)

    # Convert query vector to JSON format for vec_f32()
    # sqlite-vec's vec_f32() function accepts JSON arrays: '[1.0, 2.0, 3.0]'
    query_json = Jason.encode!(query_vector)

    # Use raw SQL for vector similarity search
    # sqlite-vec uses vec_distance_cosine for cosine distance
    query = """
    SELECT *
    FROM functions
    WHERE embedding IS NOT NULL
    ORDER BY vec_distance_cosine(embedding, vec_f32(?))
    LIMIT ?
    """

    case Repo.query(query, [query_json, limit]) do
      {:ok, %{rows: rows, columns: columns}} ->
        # Convert rows to Function structs
        Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Map.new()
          |> atomize_keys()
          |> then(&struct(Function, &1))
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Lists all functions associated with a given file path.
  Returns a list of Function structs.
  """
  def list_by_path(path) when is_binary(path) do
    import Ecto.Query

    from(f in Function,
      where: f.path == ^path
    )
    |> Repo.all()
  end

  @doc """
  Marks a function for deletion.
  Preserves all data including checksum for potential reuse on rename.
  """
  def mark_for_deletion(%Function{} = function) do
    function
    |> Function.mark_for_deletion_changeset()
    |> Repo.update()
  end

  @doc """
  Garbage collects all functions marked for deletion.
  Called on application startup to clean up stale data.
  Returns {count, nil} where count is the number of deleted functions.
  """
  def garbage_collect_marked do
    import Ecto.Query

    from(f in Function, where: f.marked_for_deletion == true)
    |> Repo.delete_all()
  end

  # Helper to convert string keys to atoms for struct creation
  defp atomize_keys(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
