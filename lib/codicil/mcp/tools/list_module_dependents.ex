defmodule Codicil.MCP.Tools.ListModuleDependents do
  use Codicil.MCP.Tool, """
  List all modules that depend on a given module (reverse dependency lookup).

  Use this tool when:
  - Understanding the impact of changing a module
  - Planning deprecation of a module or API
  - Finding all consumers of a shared utility module
  - Assessing risk before refactoring

  Examples:
  - Find all modules that use a shared helper before modifying it
  - Identify consumers of a library module before making breaking changes
  - Understand how widely used a module is in the codebase

  Returns: List of modules that depend on the target module, with dependency types.
  """

  alias Codicil.Db.ModuleDependency
  alias Codicil.Db.Repo
  alias Codicil.Modules

  @doc """
  Find all modules that depend on the specified module.

  ## Parameters
  - `moduleName` - Module name (e.g., "MyModule" or ":gen_server")
  - `type` - Optional filter: "compiler" for compile-time or "runtime" for runtime dependents

  ## Returns
  - `{:ok, text}` with formatted list of dependents
  - `{:error, reason}` if module not found
  """
  def call(%{"moduleName" => module_name} = args) do
    normalized_module = Codicil.MCP.normalize_module_name(module_name)

    case Modules.get(normalized_module) do
      nil ->
        {:error, "Module #{module_name} not found"}

      module ->
        type_filter = Map.get(args, "type")
        dependents = list_dependents_with_type(module, type_filter)

        if Enum.empty?(dependents) do
          {:ok, "No dependents found for #{module_name}"}
        else
          result = format_dependents(dependents, module_name, type_filter)
          {:ok, result}
        end
    end
  end

  defp list_dependents_with_type(module, nil) do
    # Get all dependents with their types
    import Ecto.Query

    from(md in ModuleDependency,
      join: m in Codicil.Db.Module,
      on: md.dependent_id == m.id,
      where: md.dependency_id == ^module.id,
      select: {m, md.type}
    )
    |> Repo.all()
  end

  defp list_dependents_with_type(module, "compiler") do
    module
    |> Modules.list_compile_dependents()
    |> Enum.map(fn dep -> {dep, :compiler} end)
  end

  defp list_dependents_with_type(module, "runtime") do
    module
    |> Modules.list_runtime_dependents()
    |> Enum.map(fn dep -> {dep, :runtime} end)
  end

  defp format_dependents(dependents, module_name, type_filter) do
    count = length(dependents)

    type_desc =
      case type_filter do
        "compiler" -> " (compile-time only)"
        "runtime" -> " (runtime only)"
        _ -> ""
      end

    dep_list =
      dependents
      |> Enum.map(fn {dep, type} ->
        type_label = format_type(type)
        "- #{dep.id} [#{type_label}] (#{dep.path})"
      end)
      |> Enum.join("\n")

    """
    Found #{count} #{if count == 1, do: "dependent", else: "dependents"} for #{module_name}#{type_desc}:

    #{dep_list}
    """
  end

  defp format_type(:compiler), do: "compile-time"
  defp format_type(:runtime), do: "runtime"
end
