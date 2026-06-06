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
    {:ok, parent_hash_hexa} = Base.decode16(parent_tree_hash, case: :mixed)

    header = "commit #{byte_size(extract_content_of_tree_file(tree_hash))}\n"
    parent = "parent #{parent_hash_hexa}\n"
    author = "Max Benner <test@test.com> 1234567890 +0000\n"
    committer = "Max Benner <test@test.com> 1234567890 +0000\n"
    empty_line = "\n"

    commit_str = header <> parent <> author <> committer <> empty_line <> message
    compressed_commit = :zlib.compress(commit_str)
    sha = :crypto.hash(:sha, commit_str) |> Base.encode16(case: :lower)
    IO.write(sha)
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
