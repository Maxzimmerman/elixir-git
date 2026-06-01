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

      _ ->
        raise "Unknown command #{command}"
    end
  end
end
