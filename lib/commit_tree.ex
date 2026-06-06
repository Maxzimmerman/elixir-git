defmodule Commands.CommitTree do
  @behaviour Command

  def execute() do
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
    tree = "tree #{tree_hash}"
    parent = "parent #{parent_tree_hash}\n"
    author = "author Max Benner <test@test.com> 1234567890 +0000\n"
    committer = "committer Max Benner <test@test.com> 1234567890 +0000\n"
    empty_line = "\n"

    store = tree <> parent <> author <> committer <> empty_line <> message
    header = "commit #{byte_size(store)}\0"

    commit = header <> store
    sha = :crypto.hash(:sha, commit) |> Base.encode16(case: :lower)
    compressed = :zlib.compress(commit)

    <<dir::binary-size(2), rest::binary>> = sha
    File.mkdir_p(".git/objects/#{dir}")
    File.write(".git/objects/#{dir}/#{rest}", compressed)
    IO.puts(sha)
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
