defmodule Git do
  def create_blob_with_file_content(content) do
    header = "blob #{byte_size(content)}\0"
    store = header <> content
    compressed = :zlib.compress(store)
    sha = :crypto.hash(:sha, store) |> Base.encode16(case: :lower)

    <<dir::binary-size(2), rest::binary>> = sha

    File.mkdir!(".git/objects/#{dir}")
    File.write(".git/objects/#{dir}/#{rest}", compressed)

    sha
  end

  def create_blob_with_file(file) do
    {:ok, content} = File.read(file)
    header = "blob #{byte_size(content)}\0"
    store = header <> content
    compressed = :zlib.compress(store)
    sha = :crypto.hash(:sha, store) |> Base.encode16(case: :lower)

    <<dir::binary-size(2), rest::binary>> = sha

    File.mkdir!(".git/objects/#{dir}")
    File.write(".git/objects/#{dir}/#{rest}", compressed)

    sha
  end

  def create_tree_with_file(dir) do
    {:ok, stat} = File.stat!(dir)

    # header 
    header = "tree #{bit_size(dir)}\0"

    # body
    {:ok, files} = File.ls(dir)
    blobs = build_blobs(files, [])
    IO.inspect(blobs)
  end

  def build_blobs([file | rest], hashes) do
    {sha, mode} =
      case File.read("./#{file}") do
        {:ok, file_bites} ->
          {:ok, stat} = File.stat(file)
          {create_blob_with_file_content(file_bites), stat.mode}
      end

    build_blobs(rest, [[file, sha, mode] | hashes])
  end

  def build_blobs(_, hashes), do: hashes
end
