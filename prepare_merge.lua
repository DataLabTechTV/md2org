function dir_as_title(s)
  local title = s:gsub("[-_]+", " ")
  title = title:gsub(
    "(%a)([%w]*)", function(first, rest)
      return first:upper() .. rest:lower()
  end)
  return title
end

function Pandoc(doc)
  -- Number of levels to add above source headings
  local n = 1

  -- Create path headers, if the option is set
  local path_headers = {}
  local root = pandoc.utils.stringify(doc.meta.root or "null")
  local path_as_headings_root = pandoc.utils.stringify(doc.meta.path_as_headings_root or "null")
  if root ~= "null" and path_as_headings_root ~= "null" then
    local root = pandoc.path.join({ root, path_as_headings_root })
    local dirname = pandoc.path.directory(pandoc.path.make_relative(PANDOC_STATE.input_files[1], root))
    local parts = pandoc.path.split(dirname)
    n = n + #parts
    for i, part in ipairs(parts) do
      local path_header = pandoc.Header(i+1, dir_as_title(part))
      path_headers[#path_headers + 1] = path_header
    end
  end

  -- Increase all heading levels by 1
  local doc = doc:walk {
    Header = function(h)
      h.level = h.level + n + 1
      return h
    end
  }

  -- Insert the path as headings
  for i, path_header in ipairs(path_headers) do
    table.insert(doc.blocks, i, pandoc.Para({}))
    table.insert(doc.blocks, i, path_header)
  end

  -- Create a title header
  local title = pandoc.utils.stringify(doc.meta.title or "")
  if title == "" then
    error("no title found")
  end
  local title_header = pandoc.Header(n+1, title)

  -- If a todo keyword is specified, prefix the title header with it
  local todo = pandoc.utils.stringify(doc.meta.todo or "null")
  if todo ~= "null" then
    table.insert(title_header.content, 1, pandoc.Space())
    table.insert(title_header.content, 1, todo)
  end

  -- Insert the title heading
  table.insert(doc.blocks, n, pandoc.Para({}))
  table.insert(doc.blocks, n, title_header)

  return doc
end
