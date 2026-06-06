defmodule Commands.CommitTree do
  @behaviour Command

  def execute() do
    IO.inspect(System.argv())
    create_commit(System.argv())
  end

  def create_commit([
        "commit-tree",
        tree_hash,
        "-p",
        parent_tree_hash,
        "-m",
        message
      ]) do
    IO.puts("wiht parent")
    IO.puts(tree_hash)
    IO.puts(is_binary(parent_tree_hash))
    IO.puts(message)
    {:ok, parent_hash_hexa} = Base.decode16(parent_tree_hash)

    header = "commit #{byte_size(extract_content_of_tree_file(tree_hash))}\n"
    parent = "parent #{parent_hash_hexa}"
    IO.inspect(header)
    IO.inspect(parent)
  end

  def create_commit([
        "commit-tree",
        tree_hash,
        "-m",
        message
      ]) do
    IO.puts("without parent")
  end

  defp extract_content_of_tree_file(tree_hash) do
    <<dir::binary-size(2), file_hash::binary>> = tree_hash
    {:ok, compressed_tree_content} = File.read(".git/objects/#{dir}/#{file_hash}")
    decompressed = :zlib.uncompress(compressed_tree_content)
  end
end
