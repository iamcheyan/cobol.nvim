local M = {}

function M.get_info(opts)
  local info = require("cobol.statusline").get_info(opts)
  if not info then
    return nil
  end
  local segments = {}
  if info.format then
    table.insert(segments, { text = info.format, icon = "󰌗", icon_hl = "Type", hl = "Type", type = "symbol" })
  end
  if info.area then
    table.insert(segments, { text = info.area, icon = "󰏗", icon_hl = "Identifier", hl = "Identifier", type = "symbol" })
  end
  if info.breadcrumb and info.breadcrumb ~= "" then
    local parts = vim.split(info.breadcrumb, "%s*>%s*")
    for idx, part in ipairs(parts) do
      if part ~= "" then
        local icon = "󰆧"
        if idx == 1 then
          icon = "󰏗"
        elseif part:match("^%d%d") then
          icon = "󰅪"
        end
        table.insert(segments, {
          text = part,
          icon = icon,
          icon_hl = info.breadcrumb_hl or "Function",
          hl = info.breadcrumb_hl or "Function",
          type = "symbol",
        })
      end
    end
  end
  if info.field then
    table.insert(segments, { text = info.field.name, icon = "󰅪", icon_hl = "Function", hl = "Function", type = "symbol" })
    if info.field.pic then
      table.insert(segments, { text = "PIC " .. info.field.pic, icon = "󰏿", icon_hl = "Keyword", hl = "Keyword", type = "symbol" })
    end
    table.insert(segments, { text = info.field.bytes .. " B", icon = "󰎠", icon_hl = "Number", hl = "Number", type = "symbol" })
  end
  if info.record and info.record.total_bytes then
    table.insert(segments, { text = "RECORD " .. info.record.total_bytes .. " B", icon = "󰌗", icon_hl = "Number", hl = "Number", type = "symbol" })
  end
  return {
    language = "COBOL",
    segments = segments,
    source = "cobol",
  }
end

return M
