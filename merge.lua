local function header_key(stack, h)
  local parts = {}

  for _, parent in ipairs(stack) do
    table.insert(parts, pandoc.utils.stringify(parent.content))
  end

  table.insert(parts, pandoc.utils.stringify(h.content))

  return table.concat(parts, "/")
end

function Pandoc(doc)
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
