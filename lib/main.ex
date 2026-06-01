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
        IO.inspect(hash)
        IO.inspect(Path.join(".git/objects/", hash))
        IO.inspect(File.ls(".git/objects"))

        <<first::binary-size(2), rest::binary>> = hash

        path = ".git/objects/#{first}/#{rest}"

        if File.exists?(path) do
          {:ok, content} = File.read(path)
          IO.puts(content)
        else
          IO.puts("NOT")
        end

        IO.inspect(File.ls(".git/objects/"))
        IO.inspect(File.ls(".git/refs"))
        IO.inspect(File.ls(".git"))

      _ ->
        raise "Unknown command #{command}"
    end
  end
end
