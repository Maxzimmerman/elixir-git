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

  defp decode_file_name(<<tree::binary-size(4), size::binary-size(2), rest::binary>>) do
    IO.inspect(Base.encode64(tree))
  end
end
