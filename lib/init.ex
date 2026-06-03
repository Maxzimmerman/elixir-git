defmodule Commands.Init do
  @behaviour Command

  def execute do
    File.mkdir!(".git")
    File.mkdir!(".git/objects")
    File.mkdir!(".git/refs")
    File.write!(".git/HEAD", "ref: refs/heads/main\n")
    IO.puts("Initialized git directory")
  end
end
