defmodule Commands.WriteTree do
  @behaviour Command

  @git_file_mode "100644"
  @git_dir_mode "40000"

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
    #   graph = build_graph(["."], %{})
    #   IO.inspect(graph)
    #   dfs(graph, ".")
    write_tree(".")
  end

  def write_tree(dir) do
    entries =
      File.ls!(dir)
      |> Enum.reject(&(&1 == ".git"))
      |> Enum.map(fn name ->
        path = Path.join(dir, name)

        cond do
          File.dir?(path) -> {@git_dir_mode, name, write_tree(path)}
          true -> {@git_file_mode, name, Git.create_blob_with_file(path)}
        end
      end)
      |> Enum.sort_by(fn {_, name, _} -> name end)

    entry_bytes =
      entries
      |> Enum.map(fn {mode, name, hex_sha} ->
        nil

        # build "<mode> <name>\0<20_raw_bytes>"
      end)
      |> IO.iodata_to_binary()

    header = "tree <byte_size of entry_bytes>\0"
    store = header <> entry_bytes
    sha = :crypto.hash(:sha, store) |> Base.encode16(case: :lower)

    # write store (compressed) to .git/objects/<2>/<38>
    # return sh
    IO.inspect(entries, limit: :infinity)
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

      if neighbors == [] do
        file_sha = Git.create_blob_with_file(node)
        IO.puts("BUILD BLOB #{file_sha}")
      else
        IO.puts("BUILD TREE")
      end

      IO.puts("DFS RUN #{node} neibhors: #{inspect(neighbors)}")
      dfs(graph, neighbors ++ stack, MapSet.put(visited, node), [node | acc])
    end
  end
end
