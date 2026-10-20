local M = {}

-- Pad string with spaces on the right up to len
local function pad_right(str, len)
  if #str < len then
    return str .. string.rep(" ", len - #str)
  end
  return str
end

-- RENUM: renumber sequence numbers in columns 1-6, and optionally label columns 73-80
function M.renum(bufnr, start_line, end_line, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return false end

  opts = opts or {}
  local start_num = tonumber(opts.start) or 100
  local step = tonumber(opts.step) or 100
  local label = opts.label

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  start_line = math.max(1, math.min(start_line or 1, total_lines))
  end_line = math.max(start_line, math.min(end_line or total_lines, total_lines))

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local new_lines = {}
  local curr_num = start_num

  for _, line in ipairs(lines) do
    local seq_str = string.format("%06d", curr_num % 1000000)
    curr_num = curr_num + step

    -- Ensure line has at least 6 characters
    local padded = pad_right(line, 6)
    local rest = padded:sub(7)
    local updated = seq_str .. rest

    if label and label ~= "" then
      -- Pad line to 72 characters so columns 73-80 can be placed
      if #updated < 72 then
        updated = pad_right(updated, 72)
      end
      local before_73 = updated:sub(1, 72)
      local formatted_label = pad_right(label:sub(1, 8), 8)
      local after_80 = #updated > 80 and updated:sub(81) or ""
      updated = before_73 .. formatted_label .. after_80
    end

    table.insert(new_lines, updated)
  end

  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
  vim.notify(string.format("COBOL Renum: updated lines %d..%d (start=%d, step=%d%s)",
    start_line, end_line, start_num, step, label and (", label=" .. label) or ""),
    vim.log.levels.INFO)
  return true
end

-- UNNUM: clear sequence numbers in columns 1-6 (and optionally clear identification in 73-80)
function M.unnum(bufnr, start_line, end_line, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return false end

  opts = opts or {}
  local clear_ident = opts.clear_ident ~= false -- default true

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  start_line = math.max(1, math.min(start_line or 1, total_lines))
  end_line = math.max(start_line, math.min(end_line or total_lines, total_lines))

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local new_lines = {}

  for _, line in ipairs(lines) do
    local updated = line
    if #updated > 0 then
      local padded = pad_right(updated, 6)
      local rest = padded:sub(7)
      updated = "      " .. rest
    end

    if clear_ident and #updated > 72 then
      local prefix = updated:sub(1, 72)
      -- Trim trailing whitespace from prefix if 73+ was cleared
      updated = prefix:gsub("%s+$", "")
    end

    table.insert(new_lines, updated)
  end

  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
  vim.notify(string.format("COBOL Unnum: cleared sequence numbers in lines %d..%d", start_line, end_line), vim.log.levels.INFO)
  return true
end

return M
