function Pandoc(doc)
  -- Increase all heading levels by 1
  local doc = doc:walk {
    Header = function(h)
      h.level = h.level + 1
      return h
    end
  }

  -- Create a top-level section with a heading equal to the title
  local title = pandoc.utils.stringify(doc.meta.title or "")
  if title == "" then
    error("no title found")
  end
  local header = pandoc.Header(1, title)

  -- If a todo keyword is specified, prefix the top-level heading with it
  local todo = pandoc.utils.stringify(doc.meta.todo or "null")
  if todo ~= "null" then
    table.insert(header.content, 1, pandoc.Space())
    table.insert(header.content, 1, todo)
  end

  -- Insert the top-level heading into the document
  table.insert(doc.blocks, 1, pandoc.Para({}))
  table.insert(doc.blocks, 1, header)

  return doc
end
