local prop_order = {
  "doc_title",
  "tags",
  "research",
  "channel",
  "title",
  "author",
  "year",
  "type",
  "source",
  "topic",
  "audience",
  "series",
  "part",
  "episode"
}

local idx = 1

local function insert_prop(doc, prop, val)
  table.insert(
    doc.blocks,
    idx,
    pandoc.RawBlock(
      "org",
      "#+PROPERTY: " .. string.lower(prop) .. " " ..
      pandoc.utils.stringify(val)
    )
  )

  idx = idx + 1
end

function Pandoc(doc)
  local title

  for _, prop in ipairs(prop_order) do
    if doc.meta[prop] then
      if prop == "doc_title" then
        title = pandoc.utils.stringify(doc.meta.title or "")
        doc.meta.title = doc.meta[prop]

      elseif prop == "title" then
        if title ~= "" then
          insert_prop(doc, "title", title)
        end

      elseif prop == "author" then
        insert_prop(doc, prop, doc.meta[prop])
        doc.meta.author = nil

      elseif prop == "tags" then
        local tags = {}

        for _, tag in ipairs(doc.meta.tags) do
          tag = pandoc.utils.stringify(tag)
            :gsub("-", "_")
          table.insert(tags, tag)
        end

        if doc.meta.research then
          for _, tag in ipairs(doc.meta.research) do
            tag = pandoc.utils.stringify(tag)
              :gsub("-", "_")
            table.insert(tags, tag)
          end
          doc.meta.research = nil
        end

        table.insert(
          doc.blocks,
          idx,
          pandoc.RawBlock(
            "org",
            "#+filetags: :" .. table.concat(tags, ":") .. ":"
          )
        )

        idx = idx + 1

      else
        insert_prop(doc, prop, doc.meta[prop])
      end
    end
  end

  local prop_in_order = {}
  for _, prop in ipairs(prop_order) do
    prop_in_order[prop] = true
  end

  for prop, val in pairs(doc.meta) do
    if not prop_in_order[prop] then
      insert_prop(doc, prop, doc.meta[prop])
    end
  end

  table.insert(doc.blocks, idx, pandoc.Para({}))

  return doc
end
