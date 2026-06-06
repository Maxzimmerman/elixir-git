defmodule CLI do
  @commands %{
    "init" => Commands.Init,
    "cat-file" => Commands.CatFile,
    "hash-object" => Commands.HashObject,
    "ls-tree" => Commands.LsTree,
    "write-tree" => Commands.WriteTree,
    "commit-tree" => Commands.CommitTree
  }

  defp command(name) do
    case Map.fetch(@commands, name) do
      {:ok, command} ->
        command

      _ ->
        raise "Unknown command #{name}"
    end
  end

  def main(args) do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts(:stderr, "Logs from your program will appear here!")

    command_name = List.first(args)

    command(command_name).execute()
  end
end
