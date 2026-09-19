-- lua/cobol/formatter.lua
-- Conservative COBOL keyword case formatter.

local M = {}

local keywords = {}
for _, word in ipairs({
  "ACCEPT", "ADD", "ALTER", "CALL", "CANCEL", "CLOSE", "COMPUTE", "CONTINUE", "DELETE",
  "DISPLAY", "DIVIDE", "ELSE", "END-ADD", "END-CALL", "END-COMPUTE", "END-DELETE", "END-DIVIDE",
  "END-EVALUATE", "END-IF", "END-MULTIPLY", "END-PERFORM", "END-READ", "END-RETURN", "END-SEARCH",
  "END-START", "END-STRING", "END-SUBTRACT", "END-UNSTRING", "END-WRITE", "EVALUATE", "EXIT",
  "GO", "GOBACK", "IF", "INITIALIZE", "INSPECT", "INVOKE", "MERGE", "MOVE", "MULTIPLY", "NEXT",
  "OPEN", "PERFORM", "READ", "RELEASE", "RETURN", "REWRITE", "ROLLBACK", "SEARCH", "SET",
  "SORT", "START", "STOP", "STRING", "SUBTRACT", "TO", "UNSTRING", "WHEN", "WRITE",
}) do
  keywords[word] = true
end

local function is_word_start(byte)
  return byte and ((byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122))
end

local function is_word_char(byte)
  return is_word_start(byte) or (byte and byte >= 48 and byte <= 57) or byte == 45
end

local function fixed_comment_start(line)
  if #line >= 7 and (line:sub(7, 7) == "*" or line:sub(7, 7) == "/") then
    return 7
  end
  return nil
end

function M.format_line(line)
  if not line or line == "" then
    return line or ""
  end
  local comment_start = fixed_comment_start(line)
  local out = {}
  local i = 1
  local quote

  while i <= #line do
    local char = line:sub(i, i)
    if comment_start and i >= comment_start then
      out[#out + 1] = line:sub(i)
      break
    elseif not quote and line:sub(i, i + 1) == "*>" then
      out[#out + 1] = line:sub(i)
      break
    elseif quote then
      out[#out + 1] = char
      if char == quote then
        if line:sub(i + 1, i + 1) == quote then
          out[#out + 1] = quote
          i = i + 1
        else
          quote = nil
        end
      end
      i = i + 1
    elseif char == "'" or char == '"' then
      quote = char
      out[#out + 1] = char
      i = i + 1
    elseif is_word_start(line:byte(i)) then
      local start = i
      i = i + 1
      while i <= #line and is_word_char(line:byte(i)) do
        i = i + 1
      end
      local word = line:sub(start, i - 1)
      out[#out + 1] = keywords[word:upper()] and word:upper() or word
    else
      out[#out + 1] = char
      i = i + 1
    end
  end

  return table.concat(out)
end

function M.format_range(bufnr, start_line, end_line)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  start_line = math.max(1, start_line or 1)
  end_line = math.min(vim.api.nvim_buf_line_count(bufnr), end_line or start_line)
  if end_line < start_line then
    return 0
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local changed = 0
  for index, line in ipairs(lines) do
    local formatted = M.format_line(line)
    if formatted ~= line then
      lines[index] = formatted
      changed = changed + 1
    end
  end
  if changed > 0 then
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, lines)
  end
  return changed
end

return M
