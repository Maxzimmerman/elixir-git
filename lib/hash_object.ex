defmodule Commands.HashObject do
  @behaviour Command

  def execute do
    [_, _, path] = System.argv()
    content = File.read!(path)
    sha = Git.create_blob_with_file_content(content)
    IO.puts(sha)
  end
end
