local mermaid_id = 0

function CodeBlock(block)
  if not block.classes:includes("mermaid") then
    return nil
  end

  mermaid_id = mermaid_id + 1

  local dirname = pandoc.path.directory(PANDOC_STATE.output_file)
  local diagrams_dir = pandoc.path.join({dirname, "diagrams"})
  local assets_dir = pandoc.path.join({dirname, "assets"})

  local basename = pandoc.path.filename(PANDOC_STATE.output_file)
  basename, _ = pandoc.path.split_extension(basename)
  basename = string.format("%s-%03d", basename, mermaid_id)

  local mmd_path = pandoc.path.join({diagrams_dir, basename .. ".mmd"})
  local png_path = pandoc.path.join({assets_dir, basename .. ".png"})
  png_path = pandoc.path.make_relative(png_path, dirname)

  pandoc.system.make_directory(diagrams_dir, true)
  pandoc.system.make_directory(assets_dir, true)

  local f = assert(io.open(mmd_path, "w"))
  f:write(block.text)
  f:close()

  return pandoc.Para({pandoc.Image({}, png_path)})
end
