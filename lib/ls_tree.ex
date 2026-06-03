defmodule Commands.LsTree do
  @behaviour Command

  def execute do
    [_, _, tree_hash] = System.argv()
    <<dir::binary-size(2), file_hash::binary>> = tree_hash
    {:ok, compressed_tree_content} = File.read(".git/objects/#{dir}/#{file_hash}")
    decompressed = :zlib.uncompress(compressed_tree_content)
    [_head, content] = :binary.split(decompressed, <<0>>)
    decode_file_name(content)
  end

  defp decode_file_name(<<mode::binary-size(4), 0::1, rest::binary>>) do
    IO.inspect(mode)
  end
end
