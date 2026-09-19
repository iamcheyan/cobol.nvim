-- lua/cobol/folding.lua
-- Lightweight structural folding for fixed/free-format COBOL buffers.

local M = {}

local function is_comment(line)
  return #line >= 7 and (line:sub(7, 7) == "*" or line:sub(7, 7) == "/")
end

local function data_level(line)
  local level = line:match("^%s*(%d%d)%s+")
  return level and tonumber(level) or nil
end

local function is_division(line)
  return line:match("^%s*[%w%-]+%s+DIVISION%s*%.") ~= nil
end

local function is_section(line)
  return line:match("^%s*[%w%-]+%s+SECTION%s*%.") ~= nil
end

local function is_paragraph(line)
  if line:match("^%s*[%w%-]+%s+DIVISION%s*%.") or line:match("^%s*[%w%-]+%s+SECTION%s*%.") then
    return false
  end
  return line:match("^%s*[%w%-]+%s*%.[%s]*$") ~= nil
end

local function is_group_item(line)
  return line:match("%f[%a]PIC%f[%A]") == nil and line:match("%f[%a]PICTURE%f[%A]") == nil
end

local function scan_context(bufnr, lnum)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, lnum, false)
  local division
  local section
  local level = 1

  for _, line in ipairs(lines) do
    if not is_comment(line) then
      local upper = line:upper()
      if is_division(line) then
        division = vim.trim(upper:match("^%s*[%w%-]+%s+DIVISION"))
        section = nil
        level = 1
      elseif is_section(line) then
        section = upper:match("^%s*([%w%-]+)%s+SECTION")
        level = 2
      else
        local data = data_level(line)
        if data and division == "DATA DIVISION" then
          level = math.max(3, math.floor(data / 5) + 3)
        elseif division == "PROCEDURE DIVISION" and is_paragraph(line) then
          level = 3
        elseif division == "PROCEDURE DIVISION" and level < 3 then
          level = 3
        elseif division and not section and level < 1 then
          level = 1
        end
      end
    end
  end

  return division, section, level
end

function M.get_level(bufnr, lnum)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  lnum = lnum or vim.v.lnum
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""

  if is_comment(line) then
    local _, _, level = scan_context(bufnr, lnum - 1)
    return level, false
  end

  if is_division(line) then
    return 1, true
  elseif is_section(line) then
    return 2, true
  end

  local division, _, context_level = scan_context(bufnr, lnum)
  local data = data_level(line)
  if data and division == "DATA DIVISION" then
    local level = math.max(3, math.floor(data / 5) + 3)
    return level, data <= 1 or (data == 5 and is_group_item(line))
  end

  if division == "PROCEDURE DIVISION" and is_paragraph(line) then
    return 3, true
  end

  return context_level, false
end

function M.foldexpr(lnum)
  local level, starts_fold = M.get_level(vim.api.nvim_get_current_buf(), lnum)
  if starts_fold then
    return ">" .. level
  end
  return tostring(level)
end

return M
