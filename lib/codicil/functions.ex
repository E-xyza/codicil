defmodule Codicil.Functions do
  @moduledoc """
  Context module for managing function records in the database.
  """

  alias Codicil.Db.Function
  alias Codicil.Db.Repo
  alias Ecto.Changeset

  @doc """
  Creates a new function record.
  """
  def create(attrs) do
    %Function{}
    |> changeset(attrs)
    |> Repo.insert()
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
  def get_by_mfa({module, name, arity}) when is_atom(module) and is_atom(name) and is_integer(arity) do
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
    |> changeset(attrs)
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

  defp changeset(%Function{} = function, attrs) do
    attrs = normalize_attrs(attrs)

    function
    |> Changeset.cast(attrs, [
      :name,
      :module,
      :arity,
      :exported,
      :path,
      :line,
      :parsed,
      :docs,
      :summary,
      :embedding,
      :checksum
    ])
    |> Changeset.validate_required([:name, :module, :arity, :exported, :path, :line, :checksum])
    |> maybe_set_parsed()
  end

  defp normalize_attrs(attrs) do
    attrs
    |> normalize_atom_field(:name)
    |> normalize_atom_field(:module)
  end

  defp normalize_atom_field(attrs, key) do
    case Map.get(attrs, key) do
      value when is_atom(value) and not is_nil(value) ->
        Map.put(attrs, key, Atom.to_string(value))

      _ ->
        attrs
    end
  end

  defp maybe_set_parsed(changeset) do
    if Changeset.get_field(changeset, :parsed) do
      changeset
    else
      Changeset.put_change(changeset, :parsed, DateTime.utc_now())
    end
  end
end
