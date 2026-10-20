local M = {}

M.state = {
  enabled = false,
}

local augroup = nil

local function is_in_string_or_comment(line, col)
  -- Check column 7 comment indicator
  if #line >= 7 then
    local ind = line:sub(7, 7)
    if ind == "*" or ind == "/" then
      return true
    end
  end

  -- Check whether the cursor sits inside a quoted literal. `col` is the
  -- 0-based byte column from nvim_win_get_cursor(), and this runs from
  -- InsertCharPre, where the cursor is at the insertion point; scanning
  -- line:sub(1, col) therefore covers everything left of it, including the
  -- opening quote that starts the literal.
  local in_double = false
  local in_single = false
  local prefix = line:sub(1, col)

  for i = 1, #prefix do
    local ch = prefix:sub(i, i)
    if ch == '"' and not in_single then
      in_double = not in_double
    elseif ch == "'" and not in_double then
      in_single = not in_single
    end
  end

  return in_double or in_single
end

local function on_insert_char_pre()
  if not M.state.enabled then return end

  local char = vim.v.char
  if not char or not char:match("^[a-z]$") then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  if ft ~= "cobol" and ft ~= "cbl" and ft ~= "cob" then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local col = cursor[2]

  if not is_in_string_or_comment(line, col) then
    vim.v.char = string.upper(char)
  end
end

function M.enable()
  if M.state.enabled then return end
  M.state.enabled = true
  if not augroup then
    augroup = vim.api.nvim_create_augroup("cobol_nvim_caps", { clear = true })
  end
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = augroup,
    callback = on_insert_char_pre,
  })
  vim.notify("COBOL: CAPS ON (ISPF Smart Caps mode enabled)", vim.log.levels.INFO)
end

function M.disable()
  if not M.state.enabled then return end
  M.state.enabled = false
  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
    augroup = nil
  end
  vim.notify("COBOL: CAPS OFF", vim.log.levels.INFO)
end

function M.toggle()
  if M.state.enabled then
    M.disable()
  else
    M.enable()
  end
end

return M
