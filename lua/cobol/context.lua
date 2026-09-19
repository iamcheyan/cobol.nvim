local M = {}

function M.get_info(opts)
  local info = require("cobol.statusline").get_info(opts)
  if not info then
    return nil
  end
  local segments = {
    { text = info.format, hl = "Type" },
    { text = info.area, hl = "Identifier" },
  }
  if info.breadcrumb and info.breadcrumb ~= "" then
    table.insert(segments, { text = info.breadcrumb, hl = info.breadcrumb_hl or "Identifier" })
  end
  if info.field then
    table.insert(segments, { text = info.field.name, hl = "Function" })
    if info.field.pic then
      table.insert(segments, { text = "PIC " .. info.field.pic, hl = "Keyword" })
    end
    table.insert(segments, { text = info.field.bytes .. " B", hl = "Number" })
  end
  if info.record and info.record.total_bytes then
    table.insert(segments, { text = "RECORD " .. info.record.total_bytes .. " B", hl = "Number" })
  end
  return {
    language = "COBOL",
    segments = segments,
    source = "cobol",
  }
end

return M
