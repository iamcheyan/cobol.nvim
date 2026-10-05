local cobol = require("cobol")
cobol.setup({ smart_tab = true, diagnostics = { enable = false } })

local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = "cobol"
vim.bo[buf].shiftwidth = 4
local tab_map = vim.fn.maparg("<Tab>", "i", false, true)
local backtab_map = vim.fn.maparg("<S-Tab>", "i", false, true)
assert(tab_map.buffer == 1 and tab_map.expr == 1, "FileType attach must install buffer-local expression Tab mapping")
assert(backtab_map.buffer == 1 and backtab_map.expr == 1, "FileType attach must install buffer-local expression Shift-Tab mapping")

local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

local function check(expected, label)
  local line = vim.api.nvim_get_current_line()
  assert(line == expected, label .. ": expected " .. #expected .. " spaces, got " .. #line .. " (" .. vim.inspect(line) .. ")")
end

press("i<Tab><Esc>")
check(string.rep(" ", 6), "column 1 to 7")
press("A<Tab><Esc>")
check(string.rep(" ", 7), "column 7 to 8")
press("A<Tab><Esc>")
check(string.rep(" ", 11), "column 8 to 12")
press("A<Tab><Esc>")
check(string.rep(" ", 15), "column 12 adds shiftwidth")

vim.bo[buf].tabstop = 8
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "\t" })
press("A<Tab><Esc>")
check("\t" .. string.rep(" ", 3), "tab character counts by display column")
press("A<S-Tab><Esc>")
check(string.rep(" ", 7), "Shift-Tab reverses tab-expanded indentation")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep(" ", 15) })

press("A<S-Tab><Esc>")
check(string.rep(" ", 11), "column 16 to 12")
press("A<S-Tab><Esc>")
check(string.rep(" ", 7), "column 12 to 8")
press("A<S-Tab><Esc>")
check(string.rep(" ", 6), "column 8 to 7")
press("A<S-Tab><Esc>")
check("", "column 7 to 1")

for _, case in ipairs({
  { 2, 7 }, { 6, 7 }, { 9, 12 }, { 11, 12 }, { 13, 17 },
}) do
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep(" ", case[1] - 1) })
  press("A<Tab><Esc>")
  check(string.rep(" ", case[2] - 1), "forward boundary " .. case[1])
end

for _, case in ipairs({
  { 2, 1 }, { 6, 1 }, { 9, 8 }, { 11, 8 }, { 13, 12 },
}) do
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep(" ", case[1] - 1) })
  press("A<S-Tab><Esc>")
  check(string.rep(" ", case[2] - 1), "reverse boundary " .. case[1])
end

vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "      MOVE" })
vim.api.nvim_win_set_cursor(0, { 1, 6 })
press("i<Tab><Esc>")
check("       MOVE", "leading whitespace before source")
vim.api.nvim_win_set_cursor(0, { 1, 7 })
press("i<S-Tab><Esc>")
check("      MOVE", "reverse before source")

vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "MOVE" })
press("A<S-Tab><Esc>")
check("MOVE", "source text remains on reverse")

vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "IDENTIFICATION DIVISION.", "" })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
press("i<Tab><Esc>")
assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] ~= string.rep(" ", 6), "free format must not use fixed stops")

local other = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(other)
vim.bo[other].filetype = "lua"
assert(vim.fn.maparg("<Tab>", "i", false, true).buffer ~= 1, "non-COBOL buffer must not get COBOL Tab map")
assert(vim.fn.maparg("<S-Tab>", "i", false, true).buffer ~= 1, "non-COBOL buffer must not get COBOL Shift-Tab map")

print("tab_spec: OK")
