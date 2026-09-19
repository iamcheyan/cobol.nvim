-- COBOL context component for lualine, Heirline, winbar, or statusline.

local M = {}

local areas = {
  { max = 6, name = "SEQ" },
  { max = 7, name = "IND" },
  { max = 11, name = "AREA A" },
  { max = 72, name = "AREA B" },
  { max = math.huge, name = "IDENT" },
}

local function is_cobol(bufnr)
  return vim.tbl_contains({ "cobol", "cbl", "cob" }, vim.bo[bufnr].filetype)
end

local function current_area(winid)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local column = cursor[2] + 1
  for _, area in ipairs(areas) do
    if column <= area.max then
      return area.name
    end
  end
  return "IDENT"
end

local function current_field(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local calculator = require("cobol.calculator")
  local field = calculator.parse_field_size(line)
  if field and field.pic then
    return field
  end
  return nil
end

function M.get_info(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local winid = opts.winid or vim.api.nvim_get_current_win()
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(winid) then
    return nil
  end
  if not is_cobol(bufnr) then
    return nil
  end

  local cobol = require("cobol")
  local calculator = require("cobol.calculator")
  local row = vim.api.nvim_win_get_cursor(winid)[1]
  local breadcrumb, breadcrumb_hl = cobol.get_breadcrumb(bufnr, row)
  local field = current_field(bufnr, row)
  local record
  local record_start = calculator.find_enclosing_record_start(bufnr, row)
  if record_start then
    record = calculator.calculate_record(bufnr, record_start)
  end

  return {
    format = cobol.detect_format(bufnr):upper(),
    area = current_area(winid),
    breadcrumb = breadcrumb,
    breadcrumb_hl = breadcrumb_hl,
    field = field,
    record = record,
  }
end

function M.format(opts)
  opts = opts or {}
  local info = M.get_info(opts)
  if not info then
    return ""
  end

  local highlight = opts.highlight == true
  local function styled(text, group)
    if not highlight then
      return text
    end
    return "%#" .. group .. "#" .. text .. "%*"
  end

  local parts = { styled("COBOL " .. info.format, "CobolStatusFormat") }
  if opts.show_area ~= false then
    table.insert(parts, styled(info.area, "CobolStatusArea"))
  end
  if opts.show_breadcrumb ~= false and info.breadcrumb and info.breadcrumb ~= "" then
    table.insert(parts, styled(info.breadcrumb, info.breadcrumb_hl or "CobolStatusField"))
  end
  if opts.show_field ~= false and info.field then
    local field = info.field
    local pic = field.pic and ("PIC " .. field.pic) or nil
    local field_parts = { styled(field.name, "CobolStatusField") }
    if pic then
      table.insert(field_parts, styled(pic, "CobolStatusPic"))
    end
    table.insert(field_parts, styled(field.bytes .. " B", "CobolStatusSize"))
    table.insert(parts, table.concat(field_parts, " "))
  end
  if opts.show_record ~= false and info.record and info.record.total_bytes then
    table.insert(parts, styled("RECORD " .. info.record.total_bytes .. " B", "CobolStatusRecord"))
  end

  return table.concat(parts, opts.separator or " | ")
end

M.get = M.format

-- Return a callback compatible with lualine and simple Heirline providers.
function M.component(opts)
  return function()
    return M.format(opts)
  end
end

return M
