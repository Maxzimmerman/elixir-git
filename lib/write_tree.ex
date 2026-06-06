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
    write_tree(".") |> IO.puts()
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
        raw_sha = Base.decode16!(hex_sha, case: :lower)
        <<mode::binary, " "::binary, name::binary, 0, raw_sha::binary>>
        # build "<mode> <name>\0<20_raw_bytes>"
      end)
      |> IO.iodata_to_binary()

    header = "tree #{byte_size(entry_bytes)}\0"
    store = header <> entry_bytes
    sha = :crypto.hash(:sha, store) |> Base.encode16(case: :lower)

    compressed = :zlib.compress(store)
    <<dir2::binary-size(2), rest38::binary>> = sha
    File.mkdir_p!(".git/objects/#{dir2}")
    File.write!(".git/objects/#{dir2}/#{rest38}", compressed)
    sha
  end
end
