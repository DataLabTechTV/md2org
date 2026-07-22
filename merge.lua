local function header_key(h)
  return ("%d:%s"):format(
    h.level,
    pandoc.utils.stringify(h.content))
end

function Pandoc(doc)
  local sections = {}
  local order = pandoc.List:new()

  local current = nil

  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" then
      local key = header_key(block)

      if not sections[key] then
        sections[key] = pandoc.List:new({ block })
        order:insert(key)
      end

      current = sections[key]
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
