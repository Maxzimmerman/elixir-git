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
    IO.puts(parent_tree_hash)
    IO.puts(message)

    header = "commit #{byte_size(extract_content_of_tree_file(tree_hash))}\n"
    IO.inspect(header)
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
