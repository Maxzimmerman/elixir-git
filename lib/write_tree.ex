defmodule Commands.WriteTree do
  @behaviour Command

  def execute do
    {:ok, files} = File.ls(".")
    IO.inspect(files, label: "ALL")
    dirs = Enum.filter(files, &(File.dir?(&1) and &1 != ".git"))
    files = Enum.reject(files, &File.dir?(&1))
    IO.inspect(dirs, label: "Dirs")
    IO.inspect(files, label: "Files")
    file_hashes = build_blobs(files, [])
    dir_hashes = build_trees(dirs, [])
  end

  def build_trees([dir | rest], hashes) do
    IO.inspect(File.ls("./#{dir}"), label: "for: #{dir}")
    build_trees(rest, ["1" | hashes])
  end

  def build_trees(_, hashes), do: hashes

  def build_blobs([file | rest], hashes) do
    sha =
      case File.read("./#{file}") do
        {:ok, file_bites} ->
          Git.create_blob_with_file_content(file_bites)
      end

    build_blobs(rest, [sha | hashes])
  end

  def build_blobs(_, hashes), do: hashes
end
