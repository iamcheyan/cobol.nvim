local statusline = require("cobol.statusline")

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "       DATA DIVISION.",
  "       WORKING-STORAGE SECTION.",
  "       01  WS-RECORD.",
  "           05  WS-NAME PIC X(20).",
  "       PROCEDURE DIVISION.",
  "       MAIN.",
})
vim.bo[bufnr].filetype = "cobol"
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_win_set_cursor(0, { 4, 12 })

local text = statusline.get({ bufnr = bufnr, winid = 0 })
assert(text:find("COBOL FIXED", 1, true), "status should show source format")
assert(text:find("AREA B", 1, true), "status should show the fixed-format area")
assert(text:find("WS%-NAME", 1, false), "status should show the current field")
assert(text:find("PIC X%(20%)", 1, false), "status should show the current PIC")
assert(text:find("20 B", 1, true), "status should show the current field size")
assert(text:find("RECORD 20 B", 1, true), "status should show the enclosing record size")
local highlighted = statusline.get({ bufnr = bufnr, winid = 0, highlight = true })
assert(highlighted:find("%%#CobolStatusFormat#", 1, false), "status should color the format")
assert(highlighted:find("%%#CobolStatusPic#", 1, false), "status should color the PIC clause")
assert(highlighted:find("%%#CobolStatusRecord#", 1, false), "status should color the record size")

vim.bo[bufnr].filetype = "lua"
assert(statusline.get({ bufnr = bufnr, winid = 0 }) == "", "status should be empty outside COBOL")

print("statusline_spec: OK")
