local M = {}

-- Standard ASCII to IBM EBCDIC (CP037/CP1047) mapping table for 0..127
local ASCII_TO_EBCDIC = {
  [0x00] = 0x00, [0x01] = 0x01, [0x02] = 0x02, [0x03] = 0x03,
  [0x04] = 0x37, [0x05] = 0x2D, [0x06] = 0x2E, [0x07] = 0x2F,
  [0x08] = 0x16, [0x09] = 0x05, [0x0A] = 0x25, [0x0B] = 0x0B,
  [0x0C] = 0x0C, [0x0D] = 0x0D, [0x0E] = 0x0E, [0x0F] = 0x0F,
  [0x10] = 0x10, [0x11] = 0x11, [0x12] = 0x12, [0x13] = 0x13,
  [0x14] = 0x3C, [0x15] = 0x3D, [0x16] = 0x32, [0x17] = 0x26,
  [0x18] = 0x18, [0x19] = 0x19, [0x1A] = 0x3F, [0x1B] = 0x27,
  [0x1C] = 0x1C, [0x1D] = 0x1D, [0x1E] = 0x1E, [0x1F] = 0x1F,
  [0x20] = 0x40, -- Space
  [0x21] = 0x5A, [0x22] = 0x7F, [0x23] = 0x7B, [0x24] = 0x5B,
  [0x25] = 0x6C, [0x26] = 0x50, [0x27] = 0x7D, [0x28] = 0x4D,
  [0x29] = 0x5D, [0x2A] = 0x5C, [0x2B] = 0x4E, [0x2C] = 0x6B,
  [0x2D] = 0x60, [0x2E] = 0x4B, [0x2F] = 0x61,
  -- Numbers 0-9: 0xF0 - 0xF9
  [0x30] = 0xF0, [0x31] = 0xF1, [0x32] = 0xF2, [0x33] = 0xF3,
  [0x34] = 0xF4, [0x35] = 0xF5, [0x36] = 0xF6, [0x37] = 0xF7,
  [0x38] = 0xF8, [0x39] = 0xF9,
  [0x3A] = 0x7A, [0x3B] = 0x5E, [0x3C] = 0x4C, [0x3D] = 0x7E,
  [0x3E] = 0x6E, [0x3F] = 0x6F, [0x40] = 0x7C,
  -- Uppercase A-Z
  [0x41] = 0xC1, [0x42] = 0xC2, [0x43] = 0xC3, [0x44] = 0xC4,
  [0x45] = 0xC5, [0x46] = 0xC6, [0x47] = 0xC7, [0x48] = 0xC8,
  [0x49] = 0xC9, -- A-I
  [0x4A] = 0xD1, [0x4B] = 0xD2, [0x4C] = 0xD3, [0x4D] = 0xD4,
  [0x4E] = 0xD5, [0x4F] = 0xD6, [0x50] = 0xD7, [0x51] = 0xD8,
  [0x52] = 0xD9, -- J-R
  [0x53] = 0xE2, [0x54] = 0xE3, [0x55] = 0xE4, [0x56] = 0xE5,
  [0x57] = 0xE6, [0x58] = 0xE7, [0x59] = 0xE8, [0x5A] = 0xE9, -- S-Z
  [0x5B] = 0xBA, [0x5C] = 0xE0, [0x5D] = 0xBB, [0x5E] = 0xB0,
  [0x5F] = 0x6D, [0x60] = 0x79,
  -- Lowercase a-z
  [0x61] = 0x81, [0x62] = 0x82, [0x63] = 0x83, [0x64] = 0x84,
  [0x65] = 0x85, [0x66] = 0x86, [0x67] = 0x87, [0x68] = 0x88,
  [0x69] = 0x89, -- a-i
  [0x6A] = 0x91, [0x6B] = 0x92, [0x6C] = 0x93, [0x6D] = 0x94,
  [0x6E] = 0x95, [0x6F] = 0x96, [0x70] = 0x97, [0x71] = 0x98,
  [0x72] = 0x99, -- j-r
  [0x73] = 0xA2, [0x74] = 0xA3, [0x75] = 0xA4, [0x76] = 0xA5,
  [0x77] = 0xA6, [0x78] = 0xA7, [0x79] = 0xA8, [0x7A] = 0xA9, -- s-z
  [0x7B] = 0xC0, [0x7C] = 0x4F, [0x7D] = 0xD0, [0x7E] = 0xA1,
  [0x7F] = 0x07,
}

function M.ascii_to_ebcdic_byte(b)
  return ASCII_TO_EBCDIC[b] or 0x3F -- default substitution
end

function M.text_to_ebcdic_bytes(text)
  local bytes = {}
  for i = 1, #text do
    local b = text:byte(i)
    table.insert(bytes, M.ascii_to_ebcdic_byte(b))
  end
  return bytes
end

-- Format vertical Nibbles like ISPF HEX ON:
-- Line 1: character representation
-- Line 2: high nibbles
-- Line 3: low nibbles
function M.format_nibbles(text, mode)
  local char_line = ""
  local hi_line = ""
  local lo_line = ""

  for i = 1, #text do
    local b = text:byte(i)
    local val = (mode == "ebcdic") and M.ascii_to_ebcdic_byte(b) or b
    local ch = (b >= 32 and b <= 126) and string.char(b) or "."
    char_line = char_line .. ch
    local hi = math.floor(val / 16)
    local lo = val % 16
    hi_line = hi_line .. string.format("%X", hi)
    lo_line = lo_line .. string.format("%X", lo)
  end

  return { char_line, hi_line, lo_line }
end

-- Attempt to decode COMP-3 / Packed Decimal
-- Hex string can be given directly (e.g. "01234C" or "12345D") or from bytes
function M.decode_comp3(hex_str)
  hex_str = hex_str:gsub("%s+", ""):upper()
  if not hex_str:match("^[0-9A-F]+$") then
    return nil, "Invalid hex string"
  end
  if #hex_str < 2 then
    return nil, "Hex string too short for COMP-3"
  end

  local sign_nibble = hex_str:sub(-1)
  local digit_part = hex_str:sub(1, -2)

  if not digit_part:match("^[0-9]+$") then
    return nil, "Packed digits contain non-numeric nibble before sign"
  end

  local sign = "+"
  if sign_nibble == "D" or sign_nibble == "B" then
    sign = "-"
  elseif sign_nibble == "C" or sign_nibble == "A" or sign_nibble == "E" then
    sign = "+"
  elseif sign_nibble == "F" then
    sign = "" -- unsigned
  else
    return nil, "Invalid sign nibble: " .. sign_nibble
  end

  -- Trim leading zeros but keep at least one digit
  local value = digit_part:gsub("^0+", "")
  if value == "" then value = "0" end
  if sign == "-" and value ~= "0" then
    value = "-" .. value
  elseif sign == "+" and value ~= "0" then
    value = "+" .. value
  end

  return {
    value = value,
    sign = sign_nibble,
    digits = digit_part,
    raw = hex_str,
  }
end

-- Open a floating window to inspect text in Hex & EBCDIC
function M.inspect_interactive(text)
  if not text or text == "" then
    vim.notify("COBOL Hex: Empty selection or text", vim.log.levels.WARN)
    return
  end

  -- Clip text to 64 chars per chunk to fit comfortably
  local display_text = text
  if #display_text > 64 then
    display_text = display_text:sub(1, 64)
  end

  local ispf_ebcdic = M.format_nibbles(display_text, "ebcdic")
  local ispf_ascii = M.format_nibbles(display_text, "ascii")

  local lines = {
    " COBOL / Mainframe ISPF Hex Inspector",
    "──────────────────────────────────────────────────────────",
    "Text:   " .. display_text,
    "",
    "┌─── EBCDIC View (IBM CP037 / z/OS ISPF HEX ON) ───────────┐",
    "│ CHAR: " .. ispf_ebcdic[1],
    "│ HIGH: " .. ispf_ebcdic[2],
    "│ LOW:  " .. ispf_ebcdic[3],
    "└──────────────────────────────────────────────────────────┘",
    "",
    "┌─── ASCII / UTF-8 View ───────────────────────────────────┐",
    "│ CHAR: " .. ispf_ascii[1],
    "│ HIGH: " .. ispf_ascii[2],
    "│ LOW:  " .. ispf_ascii[3],
    "└──────────────────────────────────────────────────────────┘",
  }

  -- Test COMP-3
  local clean = display_text:gsub("%s+", ""):upper()
  local comp3, err = M.decode_comp3(clean)
  if comp3 then
    table.insert(lines, "")
    table.insert(lines, "┌─── COMP-3 (Packed Decimal) Decoded ──────────────────────┐")
    table.insert(lines, string.format("│ Value: %-16s (Sign: %s, Digits: %s)", comp3.value, comp3.sign, comp3.digits))
    table.insert(lines, "└──────────────────────────────────────────────────────────┘")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "cobol_hex"

  local max_w = 64
  for _, l in ipairs(lines) do
    max_w = math.max(max_w, vim.api.nvim_strwidth(l) + 4)
  end

  local width = math.min(max_w, vim.o.columns - 4)
  local height = #lines + 1
  local row = math.max(1, math.floor((vim.o.lines - height) / 2))
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " ISPF Hex & COMP-3 ",
    title_pos = "center",
  })

  -- Keymap 'q' or '<Esc>' to close
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true })

  return win, buf
end

return M
