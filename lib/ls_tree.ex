defmodule Commands.LsTree do
  @behaviour Command

  def execute do
    [_, _, tree_hash] = System.argv()
    <<dir::binary-size(2), file_hash::binary>> = tree_hash
    {:ok, compressed_tree_content} = File.read(".git/objects/#{dir}/#{file_hash}")
    decompressed = :zlib.uncompress(compressed_tree_content)
    [_head, content] = :binary.split(decompressed, <<0>>)
    names = decode_file_name(content, [])
    IO.puts(Enum.join(names, "\n"))
  end

  defp decode_file_name(content, names) when bit_size(content) > 0 do
    [mode, rest] = :binary.split(content, " ")
    [name, <<hash::binary-size(20), rest::binary>>] = :binary.split(rest, <<0>>)
    decode_file_name(rest, [name | names])
  end

  defp decode_file_name(_, names), do: names
end
