defmodule Commands.WriteTree do
  @behaviour Command

  def execute do
    {:ok, files} = File.ls(".")
    IO.inspect(files, label: "ALL")
    dirs = Enum.filter(files, &(File.dir?(&1) and &1 != ".git"))
    files = Enum.reject(files, &File.dir?(&1))
    IO.inspect(dirs, label: "Dirs")
    IO.inspect(files, label: "Files")
    file_hashes = Git.build_blobs(files, [])
    dir_hashes = build_trees(dirs, [])
  end

  def build_trees([dir | rest], hashes) do
    IO.inspect(File.ls("#{dir}"), label: "for: #{dir}")
    build_trees(rest, ["1" | hashes])
  end

  def build_trees(_, hashes), do: hashes
end
