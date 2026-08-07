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

local function to_normalized_path(path, ft)
  if not ft then
    _, ext = pandoc.path.split_extension(path)
    ft = ext:gsub("^%.", ""):lower()
  end

  path = urldecode(path)
  path = strip_accents(path)
  path = path
    :lower()
    :gsub("([^%.])%.([^%.])", "%1-%2")
    :gsub("(.*)%-(.*)$", "%1." .. ft)
    :gsub("[ %-%–—]+", "-")
    :gsub("[',]", "")
    :gsub("&", "and")

  return path
end

function Link(link)
  -- Strip problematic characters
  local content = pandoc.utils.stringify(link.content)
  print("BEFORE: " .. content)
  content = content:gsub("[%[%]]", "")
  link.content = content
  print("AFTER: " .. content)

  -- Regular web links should remain unaltered
  if link.target:match("^https?://") then
    return link
  end

  -- Fix section links inside the same document
  if link.target:match("^#") then
    link.target = urldecode(link.target:gsub("^#", "*"))
    return link
  end

  -- Fix internal links with a fragment
  local file, fragment = link.target:match("^(.-)#(.+)$")
  if file and fragment then
    link.target = "file:" .. to_normalized_path(file, "org") .. "::*" .. fragment
    return link
  end

  -- Fix remaining internal links
  link.target = to_normalized_path(link.target, "org")

  return link
end

function Image(img)
  if not img.src:match(".*%.(png|gif|jpg|jpeg)$") then
    return pandoc.Link(
      pandoc.path.filename(img.src),
      "file:" .. to_normalized_path(img.src):gsub("attachments/", "assets/"),
      img.title,
      img.attr
    )
  end

  if img.src:match(".*%.excalidraw.md$") then
    img.src = img.src:gsub("%.excalidraw%.md$", ".png")
  end

  img.src = to_normalized_path(img.src):gsub("attachments/", "assets/")

  return img
end
