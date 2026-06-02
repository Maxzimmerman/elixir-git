defmodule CLI do
  def main(args) do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts(:stderr, "Logs from your program will appear here!")

    command = List.first(args)

    case command do
      "init" ->
        File.mkdir!(".git")
        File.mkdir!(".git/objects")
        File.mkdir!(".git/refs")
        File.write!(".git/HEAD", "ref: refs/heads/main\n")
        IO.puts("Initialized git directory")

      "cat-file" ->
        [_, _, hash] = System.argv()
        <<first::binary-size(2), rest::binary>> = hash

        path = ".git/objects/#{first}/#{rest}"

        if File.exists?(path) do
          {:ok, compressed} = File.read(path)
          decompressed = :zlib.uncompress(compressed)
          [_header, content] = :binary.split(decompressed, <<0>>)
          IO.binwrite(content)
        else
          IO.puts("NOT")
        end

      "hash-object" ->
        [_, _, path] = System.argv()
        content = File.read!(path)
        header = "blob #{byte_size(content)}\0"
        store = header <> content
        compressed = :zlib.compress(store)
        sha = :crypto.hash(:sha, store) |> Base.encode16(case: :lower)

        <<dir::binary-size(2), rest::binary>> = sha

        File.mkdir!(".git/objects/#{dir}")
        File.write(".git/objects/#{dir}/#{rest}", compressed)

        IO.puts(sha)

      "ls-tree" ->
        [_, _, tree_hash] = System.argv()
        <<dir::binary-size(2), file_hash::binary>> = tree_hash
        {:ok, tree_content} = File.read(".git/objects/#{dir}/#{file_hash}")
        decode_file_name(tree_content)

      _ ->
        raise "Unknown command #{command}"
    end
  end

  defp decode_file_name(
         <<blob::binary-size(4), size::binary-size(2), 0::1, content::binary-size(size),
           rest::binary>>
       ) do
    IO.inspect(content)
  end
end
