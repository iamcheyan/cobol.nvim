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

-- Highlight groups must follow the active theme rather than fixed colors.
vim.api.nvim_set_hl(0, "StatusLine", { fg = 0x123456, bg = 0xabcdef })
vim.api.nvim_set_hl(0, "Constant", { fg = 0x111111 })
vim.api.nvim_set_hl(0, "Type", { fg = 0x222222 })
vim.api.nvim_set_hl(0, "Function", { fg = 0x333333 })
vim.api.nvim_set_hl(0, "Special", { fg = 0x444444 })
vim.api.nvim_set_hl(0, "Number", { fg = 0x555555 })
vim.api.nvim_set_hl(0, "String", { fg = 0x666666 })
vim.api.nvim_set_hl(0, "ErrorMsg", { fg = 0x777777, bg = 0x888888 })
require("cobol").setup_highlights()
local function fg(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
end
for _, name in ipairs({ "CobolStatusFormat", "CobolStatusArea", "CobolStatusField",
  "CobolStatusPic", "CobolStatusSize", "CobolStatusRecord" }) do
  assert(fg(name) == 0x123456, name .. " must follow StatusLine")
end
for name, expected in pairs({
  CobolLevel88 = 0x111111,
  CobolConditionName = 0x222222,
  CobolLevel01 = 0x333333,
  CobolHierarchyHint = 0x444444,
  CobolSizeHint = 0x555555,
  CobolRecordSizeHint = 0x666666,
  CobolColumnOverflow = 0x777777,
}) do
  assert(fg(name) == expected, name .. " must follow its theme group")
end
assert(vim.api.nvim_get_hl(0, { name = "CobolColumnOverflow", link = false }).bg == 0x888888,
  "overflow background must follow ErrorMsg")

print("statusline_spec: OK")
