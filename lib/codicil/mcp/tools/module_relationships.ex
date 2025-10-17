defmodule Codicil.MCP.Tools.ModuleRelationships do
  @moduledoc """
  MCP tool to analyze module dependencies (imports, aliases, uses, requires, and runtime calls).
  """

  alias Codicil.Db.ModuleDependency
  alias Codicil.Db.Repo
  alias Codicil.Modules

  @doc """
  Find all module dependencies for the specified module.

  ## Parameters
  - `moduleName` - Module name (e.g., "MyModule" or ":gen_server")
  - `type` - Optional filter: "compiler" for compile-time or "runtime" for runtime dependencies

  ## Returns
  - `{:ok, text}` with formatted list of dependencies
  - `{:error, reason}` if module not found
  """
  def call(%{"moduleName" => module_name} = args) do
    normalized_module = Codicil.MCP.normalize_module_name(module_name)

    case Modules.get(normalized_module) do
      nil ->
        {:error, "Module #{module_name} not found"}

      module ->
        type_filter = Map.get(args, "type")
        dependencies = list_dependencies_with_type(module, type_filter)

        if Enum.empty?(dependencies) do
          {:ok, "No dependencies found for #{module_name}"}
        else
          result = format_dependencies(dependencies, module_name, type_filter)
          {:ok, result}
        end
    end
  end

  defp list_dependencies_with_type(module, nil) do
    # Get all dependencies with their types
    import Ecto.Query

    from(md in ModuleDependency,
      join: m in Codicil.Db.Module,
      on: md.dependency_id == m.id,
      where: md.dependent_id == ^module.id,
      select: {m, md.type}
    )
    |> Repo.all()
  end

  defp list_dependencies_with_type(module, "compiler") do
    module
    |> Modules.list_compile_dependencies()
    |> Enum.map(fn dep -> {dep, :compiler} end)
  end

  defp list_dependencies_with_type(module, "runtime") do
    module
    |> Modules.list_runtime_dependencies()
    |> Enum.map(fn dep -> {dep, :runtime} end)
  end

  defp format_dependencies(dependencies, module_name, type_filter) do
    count = length(dependencies)

    type_desc =
      case type_filter do
        "compiler" -> " (compile-time only)"
        "runtime" -> " (runtime only)"
        _ -> ""
      end

    dep_list =
      dependencies
      |> Enum.map(fn {dep, type} ->
        type_label = format_type(type)
        "- #{dep.id} [#{type_label}] (#{dep.path})"
      end)
      |> Enum.join("\n")

    """
    Found #{count} #{if count == 1, do: "dependency", else: "dependencies"} for #{module_name}#{type_desc}:

    #{dep_list}
    """
  end

  defp format_type(:compiler), do: "compile-time"
  defp format_type(:runtime), do: "runtime"
end
