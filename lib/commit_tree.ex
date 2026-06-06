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
    {:ok, parent_hash_hexa} = Base.decode16(parent_tree_hash, case: :mixed)

    parent = "parent #{parent_hash_hexa}\n"
    author = "Max Benner <test@test.com> 1234567890 +0000\n"
    committer = "Max Benner <test@test.com> 1234567890 +0000\n"
    empty_line = "\n"

    store = parent <> author <> committer <> empty_line <> message
    header = "commit #{byte_size(store)}\0tree #{tree_hash}"

    commit = store <> header
    sha = :crypto.hash(:sha, commit)

    <<dir::binary-size(2), rest::binary>> = sha
    File.mkdir_p(".git/objects/#{dir}")
    File.write(".git/objects/#{dir}/#{rest}", commit)
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
