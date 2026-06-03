defmodule Commands.HashObject do
  @behaviour Command

  def execute do
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
  end
end
