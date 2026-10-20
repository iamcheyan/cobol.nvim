local cobol = require("cobol")
local sequence = require("cobol.sequence")
local hex = require("cobol.hex")
local caps = require("cobol.caps")

cobol.setup({ diagnostics = { enable = false } })

-- 1. Test Sequence Numbering (CobolRenum & CobolUnnum)
local seq_buf = vim.api.nvim_create_buf(false, true)
vim.bo[seq_buf].filetype = "cobol"
vim.api.nvim_buf_set_lines(seq_buf, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "      *THIS IS A COMMENT",
  "       PROGRAM-ID. HELLO.",
})

-- Renum: start 100, step 100, label "MYPROG"
sequence.renum(seq_buf, 1, 3, { start = 100, step = 100, label = "MYPROG" })
local renum_lines = vim.api.nvim_buf_get_lines(seq_buf, 0, -1, false)
assert(renum_lines[1]:sub(1, 6) == "000100", "Line 1 seq must be 000100, got: " .. renum_lines[1]:sub(1, 6))
assert(renum_lines[2]:sub(1, 6) == "000200", "Line 2 seq must be 000200, got: " .. renum_lines[2]:sub(1, 6))
assert(renum_lines[3]:sub(1, 6) == "000300", "Line 3 seq must be 000300, got: " .. renum_lines[3]:sub(1, 6))

-- Column 7 indicator must be preserved!
assert(renum_lines[1]:sub(7, 7) == " ", "Line 1 col 7 must be space")
assert(renum_lines[2]:sub(7, 7) == "*", "Line 2 col 7 must be comment '*'")

-- Label in columns 73-80
assert(renum_lines[1]:sub(73, 80) == "MYPROG  ", "Line 1 col 73-80 must have label")

-- Unnum: clear sequence numbers and label
sequence.unnum(seq_buf, 1, 3, { clear_ident = true })
local unnum_lines = vim.api.nvim_buf_get_lines(seq_buf, 0, -1, false)
assert(unnum_lines[1]:sub(1, 6) == "      ", "Line 1 seq must be cleared to spaces")
assert(unnum_lines[2]:sub(1, 6) == "      ", "Line 2 seq must be cleared to spaces")
assert(unnum_lines[2]:sub(7, 7) == "*", "Line 2 comment indicator must be preserved")
assert(#unnum_lines[1] <= 72, "Col 73-80 must be cleared")

-- 2. Test Hex & EBCDIC & COMP-3 decoding
assert(hex.ascii_to_ebcdic_byte(string.byte(" ")) == 0x40, "Space in EBCDIC is 0x40")
assert(hex.ascii_to_ebcdic_byte(string.byte("A")) == 0xC1, "'A' in EBCDIC is 0xC1")
assert(hex.ascii_to_ebcdic_byte(string.byte("1")) == 0xF1, "'1' in EBCDIC is 0xF1")

local nibbles = hex.format_nibbles("AB", "ebcdic")
-- 'A' is 0xC1 -> Hi 'C', Lo '1'
-- 'B' is 0xC2 -> Hi 'C', Lo '2'
assert(nibbles[1] == "AB", "Nibbles line 1 must be text")
assert(nibbles[2] == "CC", "Nibbles line 2 must be High nibbles")
assert(nibbles[3] == "12", "Nibbles line 3 must be Low nibbles")

-- COMP-3 Decoding
local c3_pos = hex.decode_comp3("01234C")
assert(c3_pos and c3_pos.value == "+1234", "01234C must decode to +1234, got " .. tostring(c3_pos and c3_pos.value))

local c3_neg = hex.decode_comp3("0567D")
assert(c3_neg and c3_neg.value == "-567", "0567D must decode to -567, got " .. tostring(c3_neg and c3_neg.value))

local c3_uns = hex.decode_comp3("999F")
assert(c3_uns and c3_uns.value == "999", "999F must decode to 999, got " .. tostring(c3_uns and c3_uns.value))

-- 3. Test Caps mode state
caps.disable()
assert(caps.state.enabled == false, "Caps mode must be initially disabled")
caps.enable()
assert(caps.state.enabled == true, "Caps mode must be enabled after enable()")
caps.toggle()
assert(caps.state.enabled == false, "Caps mode must be disabled after toggle()")

-- 4. Test User Commands registration
local expected_commands = {
  "CobolHex",
  "CobolRenum",
  "CobolUnnum",
  "CobolCapsToggle",
  "CobolCalcRecord",
}
for _, cmd in ipairs(expected_commands) do
  assert(vim.fn.exists(":" .. cmd) == 2, "Command :" .. cmd .. " must be registered")
end

-- 5. Test get_word_under_cursor on punctuation like ').' and reserved words
local nav = require("cobol.navigation")
local test_buf = vim.api.nvim_create_buf(false, true)
vim.bo[test_buf].filetype = "cobol"
vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, {
  '       DISPLAY FUNCTION TRIM(MY-VAR).',
})
vim.api.nvim_set_current_buf(test_buf)

local line_content = vim.api.nvim_get_current_line()
local paren_col = line_content:find("%)") - 1
vim.api.nvim_win_set_cursor(0, { 1, paren_col })
local word_on_paren = nav.get_word_under_cursor()
assert(word_on_paren == nil, "get_word_under_cursor on ')' must be nil, got: " .. tostring(word_on_paren))

local dot_col = line_content:find("%.$") - 1
vim.api.nvim_win_set_cursor(0, { 1, dot_col })
local word_on_dot = nav.get_word_under_cursor()
assert(word_on_dot == nil, "get_word_under_cursor on '.' must be nil, got: " .. tostring(word_on_dot))

-- Test notification suppression: no notifications when on punctuation or reserved words
local notified_count = 0
local orig_notify = vim.notify
vim.notify = function(msg, level)
  notified_count = notified_count + 1
  return orig_notify(msg, level)
end

-- Hover on ')' must be completely silent
nav.hover_preview()
assert(notified_count == 0, "hover_preview on ')' must not produce any notification")

-- Hover on 'DISPLAY' (reserved word) must also be silent
local disp_col = line_content:find("DISPLAY") - 1
vim.api.nvim_win_set_cursor(0, { 1, disp_col })
nav.hover_preview()
assert(notified_count == 0, "hover_preview on reserved word 'DISPLAY' must not produce 'No definition' notification")

vim.notify = orig_notify

-- 6. Test Record calculation keymap <leader>cr and <leader>cl
local calc_buf = vim.api.nvim_create_buf(false, true)
vim.bo[calc_buf].filetype = "cobol"
vim.api.nvim_set_current_buf(calc_buf)
cobol.attach(calc_buf)

print("ispf_features_spec: OK")
