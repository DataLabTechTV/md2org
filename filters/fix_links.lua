local function urldecode(s)
  return s:gsub(
    "%%(%x%x)",
    function(hex)
      return string.char(tonumber(hex, 16))
    end
  )
end

-- TODO either convert to kebab case here, or adapt using the paths from meta.duckdb
local function kebab_case(s)
end

function Link(link)
  -- Regular web links should remain unaltered
  if link.target:match("^https?://") then
    return link
  end

  -- Fix section links inside the same document
  if link.target:match("^#") then
    link.target = urldecode(link.target:gsub("^#", "*"))
    return link
  end

  local input = PANDOC_STATE.input_files[1]:gsub("^data/md/", "")

  print("INPUT: " .. input)
  print("TARGET: " .. link.target)
  print("CONTENT: " .. pandoc.utils.stringify(link.content))

  local file, fragment = link.target:match("^(.-)#(.+)$")
  if file and fragment then
    print("FILE + FRAGMENT: " .. file .. " :: " .. pandoc.utils.stringify(fragment))
    link.target = urldecode(file) .. "::#" .. fragment
    print("UPDATED: " .. link.target)
  end

  -- local path = urldecode(link.target)
  -- print("PATH: " .. path)

  return link
end
