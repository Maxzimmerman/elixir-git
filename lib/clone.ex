defmodule Commands.Clone do
  @behaviour Command
  import Bitwise

  def execute do
    [_, url, dir] = System.argv()
    clone(url, dir)
  end

  def clone(url, dir) do
    File.mkdir_p!(dir)
    File.cd!(dir, fn -> do_clone(url) end)
  end

  defp do_clone(url) do
    init_git_dir()
    url = String.trim_trailing(url, "/")

    {head_sha, head_ref} = discover_refs(url)
    pack_bytes = fetch_pack(url, head_sha)
    objects = parse_pack(pack_bytes)
    resolved = resolve_deltas(objects)
    Enum.each(resolved, fn {type, content} -> write_object(type, content) end)
    write_head_ref(head_sha, head_ref)
    checkout(head_sha)
  end

  # ---------- git dir bootstrap ----------

  defp init_git_dir do
    File.mkdir_p!(".git/objects")
    File.mkdir_p!(".git/refs/heads")
    File.write!(".git/HEAD", "ref: refs/heads/main\n")
  end

  # ---------- HTTP ----------

  defp ensure_http do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
  end

  defp http_opts do
    [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ],
      autoredirect: true,
      timeout: 60_000
    ]
  end

  defp http_get(url) do
    ensure_http()
    headers = [{~c"User-Agent", ~c"git/codecrafters"}]
    {:ok, {{_, 200, _}, _hdrs, body}} =
      :httpc.request(:get, {to_charlist(url), headers}, http_opts(), body_format: :binary)
    body
  end

  defp http_post(url, content_type, body) do
    ensure_http()
    headers = [{~c"User-Agent", ~c"git/codecrafters"}]
    {:ok, {{_, 200, _}, _hdrs, resp}} =
      :httpc.request(
        :post,
        {to_charlist(url), headers, to_charlist(content_type), body},
        http_opts(),
        body_format: :binary
      )
    resp
  end

  # ---------- ref discovery ----------

  defp discover_refs(url) do
    body = http_get(url <> "/info/refs?service=git-upload-pack")
    parse_advertisement(body)
  end

  defp parse_advertisement(body) do
    refs =
      body
      |> parse_pkt_lines()
      |> Enum.reject(&(&1 == :flush))
      |> Enum.reject(&match?(<<"# service=", _::binary>>, &1))
      |> Enum.map(&parse_ref_line/1)
      |> Enum.reject(&is_nil/1)

    head_entry = Enum.find(refs, fn {_, name} -> name == "HEAD" end)
    {head_sha, _} = head_entry

    head_ref =
      refs
      |> Enum.find(fn {sha, name} -> sha == head_sha and name != "HEAD" end)
      |> case do
        nil -> "refs/heads/main"
        {_, name} -> name
      end

    {head_sha, head_ref}
  end

  defp parse_ref_line(line) do
    line = String.trim_trailing(line, "\n")
    main =
      case :binary.split(line, <<0>>) do
        [m, _caps] -> m
        [m] -> m
      end

    case :binary.split(main, " ") do
      [sha, name] when byte_size(sha) == 40 -> {sha, name}
      _ -> nil
    end
  end

  # ---------- pkt-line parsing ----------

  defp parse_pkt_lines(data), do: parse_pkt_lines(data, [])
  defp parse_pkt_lines(<<>>, acc), do: Enum.reverse(acc)

  defp parse_pkt_lines(<<"0000", rest::binary>>, acc),
    do: parse_pkt_lines(rest, [:flush | acc])

  defp parse_pkt_lines(<<len_hex::binary-size(4), rest::binary>>, acc) do
    len = String.to_integer(len_hex, 16)
    payload_size = len - 4
    <<payload::binary-size(payload_size), rest2::binary>> = rest
    parse_pkt_lines(rest2, [payload | acc])
  end

  # ---------- want / fetch ----------

  defp fetch_pack(url, head_sha) do
    caps = "multi_ack_detailed no-done side-band-64k thin-pack agent=git/codecrafters"
    body =
      pkt_line("want #{head_sha} #{caps}\n") <>
      "0000" <>
      pkt_line("done\n")

    resp = http_post(url <> "/git-upload-pack",
                     "application/x-git-upload-pack-request", body)
    extract_pack(resp, [])
  end

  defp pkt_line(payload) do
    len = byte_size(payload) + 4
    len_hex =
      len
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(4, "0")
    len_hex <> payload
  end

  defp extract_pack(<<>>, acc), do: IO.iodata_to_binary(Enum.reverse(acc))
  defp extract_pack(<<"0000", rest::binary>>, acc), do: extract_pack(rest, acc)

  defp extract_pack(<<len_hex::binary-size(4), rest::binary>>, acc) do
    len = String.to_integer(len_hex, 16)
    payload_size = len - 4
    <<payload::binary-size(payload_size), rest2::binary>> = rest

    case payload do
      <<1, pack::binary>> -> extract_pack(rest2, [pack | acc])
      <<2, _::binary>> -> extract_pack(rest2, acc)
      <<3, msg::binary>> -> raise "Server error: #{msg}"
      _ -> extract_pack(rest2, acc)
    end
  end

  # ---------- packfile parsing ----------

  defp parse_pack(<<"PACK", _ver::32, count::32, rest::binary>>) do
    parse_objects(rest, count, [])
  end

  defp parse_objects(_rest, 0, acc), do: Enum.reverse(acc)

  defp parse_objects(data, n, acc) do
    {obj, rest} = parse_one_object(data)
    parse_objects(rest, n - 1, [obj | acc])
  end

  defp parse_one_object(<<first, rest::binary>>) do
    type = band(bsr(first, 4), 0b111)
    size_lo = band(first, 0b1111)

    {_size, rest2} =
      if band(first, 0x80) == 0 do
        {size_lo, rest}
      else
        read_obj_size(rest, size_lo, 4)
      end

    case type do
      t when t in [1, 2, 3, 4] ->
        {content, rest3} = inflate_one(rest2)
        {{type_atom(t), content}, rest3}

      7 ->
        <<base_sha::binary-size(20), rest3::binary>> = rest2
        {delta, rest4} = inflate_one(rest3)
        {{:ref_delta, Base.encode16(base_sha, case: :lower), delta}, rest4}

      6 ->
        {_neg_off, rest3} = read_ofs_offset(rest2)
        {_delta, rest4} = inflate_one(rest3)
        # Not advertised in our caps; should not appear.
        raise "OFS_DELTA encountered but not implemented; rest4=#{byte_size(rest4)}"
    end
  end

  defp read_obj_size(<<byte, rest::binary>>, acc, shift) do
    new = acc + bsl(band(byte, 0x7F), shift)
    if band(byte, 0x80) == 0 do
      {new, rest}
    else
      read_obj_size(rest, new, shift + 7)
    end
  end

  defp read_ofs_offset(<<byte, rest::binary>>) do
    value = band(byte, 0x7F)
    if band(byte, 0x80) == 0 do
      {value, rest}
    else
      read_ofs_offset_loop(rest, value)
    end
  end

  defp read_ofs_offset_loop(<<byte, rest::binary>>, acc) do
    new = bsl(acc + 1, 7) + band(byte, 0x7F)
    if band(byte, 0x80) == 0 do
      {new, rest}
    else
      read_ofs_offset_loop(rest, new)
    end
  end

  defp type_atom(1), do: :commit
  defp type_atom(2), do: :tree
  defp type_atom(3), do: :blob
  defp type_atom(4), do: :tag

  # ---------- inflation ----------
  # safeInflate's :finished status is unreliable for stream-end detection.
  # zlib.uncompress/1 errors on truncated input but tolerates trailing bytes,
  # so we binary-search for the smallest prefix that decompresses cleanly.

  defp inflate_one(data) do
    size = byte_size(data)
    consumed = find_min_compressed(data, 1, size, size)
    decompressed = :zlib.uncompress(binary_part(data, 0, consumed))
    rest = binary_part(data, consumed, size - consumed)
    {decompressed, rest}
  end

  defp find_min_compressed(_data, lo, hi, best) when lo > hi, do: best

  defp find_min_compressed(data, lo, hi, best) do
    mid = div(lo + hi, 2)
    if can_uncompress?(binary_part(data, 0, mid)) do
      find_min_compressed(data, lo, mid - 1, mid)
    else
      find_min_compressed(data, mid + 1, hi, best)
    end
  end

  defp can_uncompress?(data) do
    try do
      :zlib.uncompress(data)
      true
    rescue
      _ -> false
    catch
      _, _ -> false
    end
  end

  # ---------- delta resolution ----------

  defp resolve_deltas(objects) do
    bases =
      Enum.reduce(objects, %{}, fn
        {:ref_delta, _, _}, acc -> acc
        {type, content}, acc ->
          Map.put(acc, compute_sha(type, content), {type, content})
      end)

    deltas = Enum.filter(objects, &match?({:ref_delta, _, _}, &1))

    bases = resolve_loop(deltas, bases, length(deltas))
    Map.values(bases)
  end

  defp resolve_loop([], bases, _), do: bases

  defp resolve_loop(deltas, bases, _prev_count) do
    {resolved, still_unresolved} =
      Enum.split_with(deltas, fn {:ref_delta, base_sha_hex, _} ->
        Map.has_key?(bases, base_sha_hex)
      end)

    if resolved == [] do
      raise "Cannot resolve #{length(still_unresolved)} deltas — missing bases"
    end

    new_bases =
      Enum.reduce(resolved, bases, fn {:ref_delta, base_sha_hex, delta}, acc ->
        {base_type, base_content} = Map.fetch!(acc, base_sha_hex)
        content = apply_delta(base_content, delta)
        Map.put(acc, compute_sha(base_type, content), {base_type, content})
      end)

    resolve_loop(still_unresolved, new_bases, length(deltas))
  end

  defp apply_delta(base, delta) do
    {_src_size, rest} = read_varint(delta, 0, 0)
    {_tgt_size, rest2} = read_varint(rest, 0, 0)
    apply_instructions(rest2, base, [])
  end

  defp read_varint(<<byte, rest::binary>>, acc, shift) do
    new = acc + bsl(band(byte, 0x7F), shift)
    if band(byte, 0x80) == 0 do
      {new, rest}
    else
      read_varint(rest, new, shift + 7)
    end
  end

  defp apply_instructions(<<>>, _base, acc),
    do: IO.iodata_to_binary(Enum.reverse(acc))

  defp apply_instructions(<<opcode, rest::binary>>, base, acc) do
    cond do
      band(opcode, 0x80) != 0 ->
        {offset, rest2} = read_copy_field(rest, opcode, 0, 4, 0, 0)
        {size, rest3} = read_copy_field(rest2, opcode, 4, 3, 0, 0)
        size = if size == 0, do: 0x10000, else: size
        <<_::binary-size(offset), chunk::binary-size(size), _::binary>> = base
        apply_instructions(rest3, base, [chunk | acc])

      opcode != 0 ->
        size = opcode
        <<chunk::binary-size(size), rest2::binary>> = rest
        apply_instructions(rest2, base, [chunk | acc])

      true ->
        raise "Invalid delta opcode 0"
    end
  end

  # Read N bytes from `data` selected by bits of `opcode`.
  # `start_bit` is which bit of opcode to start at (0 for offset, 4 for size).
  # `n` is how many bits to check.
  defp read_copy_field(rest, _opcode, _bit, 0, value, _shift), do: {value, rest}

  defp read_copy_field(rest, opcode, bit, n, value, shift) do
    if band(opcode, bsl(1, bit)) != 0 do
      <<b, rest2::binary>> = rest
      read_copy_field(rest2, opcode, bit + 1, n - 1, value + bsl(b, shift), shift + 8)
    else
      read_copy_field(rest, opcode, bit + 1, n - 1, value, shift + 8)
    end
  end

  # ---------- object writing ----------

  defp compute_sha(type, content) do
    store = "#{type_str(type)} #{byte_size(content)}\0" <> content
    :crypto.hash(:sha, store) |> Base.encode16(case: :lower)
  end

  defp type_str(:commit), do: "commit"
  defp type_str(:tree), do: "tree"
  defp type_str(:blob), do: "blob"
  defp type_str(:tag), do: "tag"

  defp write_object(type, content) do
    store = "#{type_str(type)} #{byte_size(content)}\0" <> content
    sha = :crypto.hash(:sha, store) |> Base.encode16(case: :lower)
    compressed = :zlib.compress(store)
    <<d::binary-size(2), r::binary>> = sha
    File.mkdir_p!(".git/objects/#{d}")
    File.write!(".git/objects/#{d}/#{r}", compressed)
    sha
  end

  # ---------- refs ----------

  defp write_head_ref(head_sha, head_ref) do
    File.mkdir_p!(Path.dirname(".git/" <> head_ref))
    File.write!(".git/" <> head_ref, head_sha <> "\n")
    File.write!(".git/HEAD", "ref: #{head_ref}\n")
  end

  # ---------- checkout ----------

  defp checkout(commit_sha) do
    {:commit, content} = read_obj(commit_sha)
    ["tree " <> tree_sha | _] = String.split(content, "\n")
    checkout_tree(tree_sha, ".")
  end

  defp checkout_tree(tree_sha, dest_dir) do
    {:tree, content} = read_obj(tree_sha)

    parse_tree_entries(content)
    |> Enum.each(fn {mode, name, entry_sha} ->
      path = Path.join(dest_dir, name)

      case mode do
        "40000" ->
          File.mkdir_p!(path)
          checkout_tree(entry_sha, path)

        "120000" ->
          {:blob, target} = read_obj(entry_sha)
          File.ln_s!(target, path)

        _ ->
          {:blob, blob_content} = read_obj(entry_sha)
          File.write!(path, blob_content)
          if mode == "100755", do: File.chmod!(path, 0o755)
      end
    end)
  end

  defp read_obj(sha) do
    <<d::binary-size(2), r::binary>> = sha
    {:ok, compressed} = File.read(".git/objects/#{d}/#{r}")
    decompressed = :zlib.uncompress(compressed)
    [header, content] = :binary.split(decompressed, <<0>>)
    [type, _size] = String.split(header, " ", parts: 2)
    {atom_for_type(type), content}
  end

  defp atom_for_type("commit"), do: :commit
  defp atom_for_type("tree"), do: :tree
  defp atom_for_type("blob"), do: :blob
  defp atom_for_type("tag"), do: :tag

  defp parse_tree_entries(<<>>), do: []

  defp parse_tree_entries(data) do
    [mode, rest] = :binary.split(data, " ")
    [name, <<sha::binary-size(20), rest2::binary>>] = :binary.split(rest, <<0>>)
    [{mode, name, Base.encode16(sha, case: :lower)} | parse_tree_entries(rest2)]
  end
end
