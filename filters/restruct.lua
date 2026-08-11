local priority_map = {
  P0 = "[#A]",
  P1 = "[#B]",
  P2 = "[#C]",
  P3 = "[#E]",
  P4 = "[#F]",
  P5 = "[#G]",
  P6 = "[#H]",
  P7 = "[#I]",
  P8 = "[#J]",
  P9 = "[#K]",
}

local meta_ignore_filetags = {}
local filetags = {}
local props = {}

local function dir_as_title(s)
  local title = s:gsub("[-_]+", " ")
  title = title:gsub(
    "(%a)([%w]*)", function(first, rest)
      return first:upper() .. rest:lower()
  end)
  return title
end

function process_meta(m)
  if m.ignore and m.ignore.filetags then
    for _, tag in ipairs(m.ignore.filetags) do
      tag = pandoc.utils.stringify(tag)
        :gsub("-", "_")
      meta_ignore_filetags[tag] = true
    end
  end

  return m
end

function process_raw_block(rb)
  if rb.format ~= "org" then
    return nil
  end

  local prop, val = rb.text:match("^#%+PROPERTY:%s*(%S+)(.*)$")
  if prop and val then
    table.insert(props, ":" .. prop .. ": " .. val)
    return {}
  end

  local tags = rb.text:match("^#%+filetags:%s*(.+)$")
  if tags then
    for tag in tags:gmatch(":([^:]+)") do
      if not meta_ignore_filetags[tag] then
        table.insert(filetags, tag)
      end
    end
    return {}
  end

  return nil
end

function Image(img)
  img.src = "assets/" .. pandoc.path.filename(img.src)
  return img
end

function Pandoc(doc)
  -- Ensure that 'meta_ignore_filetags' is loaded before raw block processing
  doc.meta = process_meta(doc.meta)
  doc = doc:walk({ RawBlock = process_raw_block })

  -- Number of levels to add above source headings
  local n = 1

  -- Create outer header, if the option is set, and update n
  local outer_header = nil
  local outer_heading = pandoc.utils.stringify(doc.meta.outer_heading or "null")
  if outer_heading ~= "null" then
    outer_header = pandoc.Header(1, outer_heading)
    n = n + 1
  end

  -- Create path headers, if the option is set, and update n

  local path_headers = {}
  local root = pandoc.utils.stringify(doc.meta.root or "null")
  local path_as_headings_root = pandoc.utils.stringify(doc.meta.path_as_headings_root or "null")

  if root ~= "null" and path_as_headings_root ~= "null" then
    local root = pandoc.path.join({ root, path_as_headings_root })
    local dirname = pandoc.path.directory(pandoc.path.make_relative(PANDOC_STATE.input_files[1], root))
    local parts = {}

    if dirname ~= "." then
      parts = pandoc.path.split(dirname)

      for i, part in ipairs(parts) do
        local path_header = pandoc.Header(i+n-1, dir_as_title(part))
        table.insert(path_headers, path_header)
      end
    end

    n = n + #parts
  end

  -- Increase all heading levels by n+1
  local doc = doc:walk {
    Header = function(h)
      h.level = h.level + n
      return h
    end
  }

  -- Insert outer heading
  if outer_header then
    table.insert(doc.blocks, 1, pandoc.Para({}))
    table.insert(doc.blocks, 1, outer_header)
  end

  -- Insert the path as headings
  for i, path_header in ipairs(path_headers) do
    table.insert(doc.blocks, i, pandoc.Para({}))
    table.insert(doc.blocks, i, path_header)
  end

  -- Create a title header with optional prefix parsing and a custom_id

  local title = pandoc.utils.stringify(doc.meta.title or "")
  if title == "" then
    error("no title found")
  end

  local custom_id, _ = pandoc.path.split_extension(
    pandoc.path.filename(PANDOC_STATE.input_files[1]))

  if doc.meta.prefix_to_priority then
    local priority_regex = "^([Pp][0-9]+)[ -]*(.*)"

    priority, real_title = title:match(priority_regex)
    priority = priority_map[priority]

    if priority then
      title = real_title .. " " .. priority
    end

    _, custom_id = custom_id:match(priority_regex)
  end

  if doc.meta.prefix_to_order then
    local order_regex = "^([0-9]+)[ -]*(.*)"

    order, real_title = title:match(order_regex)
    order = tonumber(order)

    if order then
      title = real_title
      table.insert(props, ":order: " .. order)
    end

    _, custom_id = custom_id:match(order_regex)
  end

  if doc.meta.filename_as_date then
    local date_str = pandoc.utils.normalize_date(title)

    if date_str then
      local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
      local timestamp = os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day)})

      title = "[" .. os.date("%Y-%m-%d %a", timestamp) .. "]"
    end
  end

  local title_header = pandoc.Header(n, title)

  if custom_id and custom_id ~= "" then
    table.insert(props, 1, ':custom_id: ' .. custom_id)
  end

  -- If a todo keyword is specified, prefix the title header with it
  local todo = pandoc.utils.stringify(doc.meta.todo or "null")
  if todo ~= "null" then
    table.insert(title_header.content, 1, pandoc.Space())
    table.insert(title_header.content, 1, todo)
  end

  -- If there are filetags, move them to header tags
  if #filetags > 0 then
    table.insert(title_header.content, pandoc.Space())
    table.insert(title_header.content, pandoc.Str(":" .. table.concat(filetags, ":") .. ":"))
  end

  -- Insert the title heading
  table.insert(doc.blocks, n, pandoc.Para({}))
  table.insert(doc.blocks, n, title_header)

  -- Insert any optional properties
  if #props > 0 then
    table.insert(props, 1, ":PROPERTIES:")
    table.insert(props, ":END:")
    props = table.concat(props, "\n")
    table.insert(doc.blocks, n+1, pandoc.RawBlock("org", props))
  end

  return doc
end
