defmodule Commands.WriteTree do
  @behaviour Command

  def execute do
    {:ok, files} = File.ls(".")
    IO.inspect(files)
    dirs = Enum.filter(files, &(File.dir?(&1) and &1 != ".git"))
    files = Enum.reject(files, &File.dir?(&1))
    IO.inspect(dirs)
    IO.inspect(files)
    files_hashes = build_blobs(files, [])
  end

  def build_blobs(files, hashes) do
  end

  def build_blobs(_, hashes), do: hashes
end
