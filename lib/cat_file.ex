defmodule Commands.CatFile do
  @behaviour Command

  def execute do
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
  end
end
