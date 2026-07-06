local meta = nil

function Meta(m)
  meta = m
end

function Pandoc(doc)
  if meta["merge"] ~= "yes" then
    return doc
  end

  local filename = PANDOC_STATE.input_files[1]

  if not filename then
    return doc
  end

  filename = filename:match("([^/]+)$")
  filename = filename:gsub("%.[^.]+$", "")

  local doc = doc:walk {
    Header = function(h)
      h.level = h.level + 1
      return h
    end
  }

  local header = pandoc.Header(1, filename)

  if meta["todo"] ~= "" then
    table.insert(header.content, 1, pandoc.Space())
    table.insert(header.content, 1, meta["todo"])
  end

  table.insert(doc.blocks, 1, pandoc.Para({}))
  table.insert(doc.blocks, 1, header)

  return doc
end
