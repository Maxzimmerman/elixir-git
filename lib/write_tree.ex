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
    IO.inspect(files_hashes)
  end

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
