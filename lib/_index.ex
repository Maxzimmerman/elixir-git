defmodule Git do
  def create_blob_with_file_content(content) do
    header = "blob #{byte_size(content)}\0"
    store = header <> content
    compressed = :zlib.compress(store)
    sha = :crypto.hash(:sha, store) |> Base.encode16(case: :lower)

    <<dir::binary-size(2), rest::binary>> = sha

    File.mkdir!(".git/objects/#{dir}")
    File.write(".git/objects/#{dir}/#{rest}", compressed)

    sha
  end
end
