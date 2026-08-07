local org_remapped_dir = nil

function process_meta(m)
  org_remapped_dir = m.org_remapped_dir
  return m
end

function process_header(header)
  if header.identifier and header.identifier ~= "" then
    local rel_path = pandoc.path.make_relative(PANDOC_STATE.input_files[1], org_remapped_dir)
    local custom_id = header.identifier
    print(string.format("%s\t%s", rel_path, custom_id))
  end

  return header
end

function Pandoc(doc)
  -- Ensure that 'org_remapped_dir' is loaded before header processing
  doc.meta = process_meta(doc.meta)
  doc = doc:walk({ Header = process_header })
  return doc
end
