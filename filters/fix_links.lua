local accents = {
  ["á"]="a", ["à"]="a", ["â"]="a", ["ä"]="a", ["ã"]="a", ["å"]="a",
  ["Á"]="A", ["À"]="A", ["Â"]="A", ["Ä"]="A", ["Ã"]="A", ["Å"]="A",

  ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e",
  ["É"]="E", ["È"]="E", ["Ê"]="E", ["Ë"]="E",

  ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
  ["Í"]="I", ["Ì"]="I", ["Î"]="I", ["Ï"]="I",

  ["ó"]="o", ["ò"]="o", ["ô"]="o", ["ö"]="o", ["õ"]="o",
  ["Ó"]="O", ["Ò"]="O", ["Ô"]="O", ["Ö"]="O", ["Õ"]="O",

  ["ú"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u",
  ["Ú"]="U", ["Ù"]="U", ["Û"]="U", ["Ü"]="U",

  ["ç"]="c", ["Ç"]="C",
  ["ñ"]="n", ["Ñ"]="N",
}

local function strip_accents(s)
  return s:gsub(
    "[%z\1-\127\194-\244][\128-\191]*",
    function(c)
      return accents[c] or c
    end
  )
end

local function urldecode(s)
  return s:gsub(
    "%%(%x%x)",
    function(hex)
      return string.char(tonumber(hex, 16))
    end
  )
end

local function to_normalized_org_path(path)
  path = urldecode(path)
  path = strip_accents(path)
  path = path
    :lower()
    :gsub("([^%.])%.([^%.])", "%1-%2")
    :gsub("(.*)%-(.*)$", "%1.org")
    :gsub("[ %-%–—]+", "-")
    :gsub("[',]", "")
    :gsub("&", "and")

  return path
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

  -- print("CONTENT: " .. pandoc.utils.stringify(link.content))
  -- print("TARGET: " .. link.target)
  -- -- TODO fix file/image links
  -- print("UPDATED: " .. link.target)

  -- Fix internal links with a fragment
  local file, fragment = link.target:match("^(.-)#(.+)$")
  if file and fragment then
    link.target = "file:" .. to_normalized_org_path(file) .. "::*" .. fragment
    return link
  end

  -- Fix remaining internal links
  link.target = to_normalized_org_path(link.target)

  return link
end
