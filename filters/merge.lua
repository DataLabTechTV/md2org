local output_dir = nil
local org_remapped_dir = nil
local merged_links = nil

local function header_key(stack, h)
  local parts = {}

  for _, parent in ipairs(stack) do
    table.insert(parts, pandoc.utils.stringify(parent.content))
  end

  table.insert(parts, pandoc.utils.stringify(h.content))

  return table.concat(parts, "/")
end

function process_meta(m)
  org_remapped_dir = m.org_remapped_dir
  merged_links = m.merged_links
  return m
end

function process_link(link)
  if merged_links[link.target] then
    local merged_link = pandoc.utils.stringify(merged_links[link.target].merged_link)
    local custom_id = pandoc.utils.stringify(merged_links[link.target].custom_id)
    merged_link = pandoc.path.join({ org_remapped_dir, merged_link })
    link.target = "file:" .. pandoc.path.make_relative(merged_link, output_dir, true) .. '::#' .. custom_id
  end

  return link
end

function Pandoc(doc)
  -- Ensure that 'merged_links' and 'output_dir' are set before Link processing
  doc.meta = process_meta(doc.meta)
  output_dir = pandoc.path.join({
      pandoc.system.get_working_directory(),
      pandoc.path.directory(PANDOC_STATE.output_file)
  })
  doc = doc:walk({ Link = process_link })

  local sections = {}
  local order = pandoc.List:new()

  local current = nil
  local stack = {}

  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" then
      while #stack > 0 and stack[#stack].level >= block.level do
        table.remove(stack)
      end

      local key = header_key(stack, block)

      if not sections[key] then
        sections[key] = pandoc.List:new({ block })
        order:insert(key)
      end

      current = sections[key]
      stack[#stack + 1] = block
    else
      if current then
        current:insert(block)
      end
    end
  end

  local blocks = pandoc.List:new()

  for _, key in ipairs(order) do
    blocks:extend(sections[key])
  end

  doc.blocks = blocks
  return doc
end
