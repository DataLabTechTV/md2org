local org_remapped_dir = nil

function process_meta(m)
  org_remapped_dir = m.org_remapped_dir
  return m
end

function to_relative(path)
  local cmd = string.format([[
      realpath \
        --canonicalize-missing \
        --relative-to="%s" \
        "%s"
    ]],
    org_remapped_dir,
    path
  )

  local proc = io.popen(cmd)
  path = proc:read("*l")
  proc:close()

  return path
end

function process_link(link)
  if link.target:match("^https?://")
    or link.target:match("^*")
    or link.target:match(".*(assets|diagrams)/.*") then

    return link
  end

  local scheme, rest = link.target:match("^(file:)(.*)$")
  local path, anchor

  if scheme then
    path, anchor = rest:match("^([^*]*)(*?.*)$")
  else
    path, anchor = link.target, ""
  end

  local current_dir = pandoc.path.directory(PANDOC_STATE.input_files[1])
  local abs_path = to_relative(pandoc.path.join({current_dir, link.target}))

  print(string.format("%s\t%s\t%s", to_relative(current_dir), link.target, abs_path))

  return link
end

function Pandoc(doc)
  -- Ensure that 'org_remapped_dir' is loaded before link processing
  doc.meta = process_meta(doc.meta)
  doc = doc:walk({ Link = process_link })
  return doc
end
