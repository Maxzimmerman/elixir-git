defmodule Commands.WriteTree do
  @behaviour Command

  def execute do
    # {:ok, files} = File.ls(".")
    # IO.inspect(files, label: "ALL")
    # dirs = Enum.filter(files, &(File.dir?(&1) and &1 != ".git"))
    # files = Enum.reject(files, &File.dir?(&1))
    # IO.inspect(dirs, label: "Dirs")
    # IO.inspect(files, label: "Files")
    # file_hashes = Git.build_blobs(files, [])
    # dir_hashes = build_trees(dirs, [])
    # IO.inspect(dir_hashes, label: "Dir hashes")
    graph = build_graph(["."], %{})
    IO.inspect(graph)
    dfs(graph, ".")
  end

  def build_trees([dir | rest], hashes) do
    IO.inspect(File.ls("#{dir}"), label: "for: #{dir}")
    Git.create_tree_with_file(dir)
    build_trees(rest, ["1" | hashes])
  end

  def build_trees(_, hashes), do: hashes

  def build_graph([], graph_acc), do: graph_acc

  def build_graph([dir_name | rest], graph_acc) do
    case File.ls(dir_name) do
      {:ok, files} ->
        dirs =
          Enum.filter(files, &(File.dir?(&1) and &1 != ".git"))
          |> Enum.map(&"#{dir_name}/#{&1}")

        files =
          Enum.reject(files, &File.dir?(&1))
          |> Enum.map(&"#{dir_name}/#{&1}")

        build_graph(rest ++ dirs ++ files, Map.put(graph_acc, dir_name, files ++ dirs))

      {:error, :enotdir} ->
        build_graph(rest, graph_acc)
    end
  end

  def dfs(graph, start) do
    dfs(graph, [start], MapSet.new(), [])
    |> Enum.reverse()
  end

  defp dfs(_graph, [], _visited, acc), do: acc

  defp dfs(graph, [node | stack], visited, acc) do
    if MapSet.member?(visited, node) do
      dfs(graph, stack, visited, acc)
    else
      neighbors = Map.get(graph, node, [])
      dfs(graph, neighbors ++ stack, MapSet.put(visited, node), [node | acc])
    end
  end
end
