-- Winbar regression tests: the breadcrumb chain must be clipped by the plugin
-- instead of letting Neovim truncate it, and the waiting closures must stay on
-- the right-hand side. Headless Neovim keeps an 80-column window, so the layouts
-- are exercised by choosing fixtures that do and do not fit in 80 columns.
local cobol = require("cobol")

local function attach(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "cobol"
  vim.api.nvim_set_current_buf(buf)
  cobol.attach(buf)
  return buf
end

local function render()
  local winbar = cobol.get_winbar()
  return winbar, vim.api.nvim_eval_statusline(winbar, { winid = 0, use_winbar = true }).str
end

local function place(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
end

cobol.setup({ show_winbar = true, diagnostics = { enable = false } })
local width = vim.api.nvim_win_get_width(0)

-- 1. Short chain: breadcrumb and waiting closures both fit.
local short = attach({
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. SHORT.",
  "       PROCEDURE DIVISION.",
  "       SHORT-PARA.",
  "           IF A > 1",
  "               DISPLAY \"X\"",
  "           END-IF.",
  "           STOP RUN.",
})
place(6, 20)
local short_option, short_text = render()
assert(short_text:find("PROCEDURE DIVISION", 1, true), "winbar must show the division: " .. short_text)
assert(short_text:find("SHORT-PARA", 1, true), "winbar must show the paragraph: " .. short_text)
assert(short_text:find("IF A > 1", 1, true), "winbar must show the enclosing IF: " .. short_text)
assert(short_text:find("END-IF", 1, true), "winbar must show waiting closures: " .. short_text)
assert(short_text:find("%%=", 1, true) == nil, "the right-align marker must not render literally")
assert(vim.api.nvim_strwidth(short_text) <= width, "winbar must fit the window")
assert(short_option:find("%#CobolBreadcrumbProc#", 1, true), "breadcrumb must use the division highlight")

-- 2. Long chain: clipped from the left, innermost parts kept, waiting closures
-- dropped rather than squeezing the chain away, and Neovim's own "<"
-- truncation marker must never appear.
local long = attach({
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. VALIDATOR.",
  "       PROCEDURE DIVISION.",
  "       INPUT-SECTION SECTION.",
  "       VALIDATE-INPUT-PARAGRAPH.",
  "           IF STATUS = \"A\"",
  "               EVALUATE TXN-TYPE",
  "                 WHEN \"D\"",
  "                   DISPLAY \"OK\"",
  "               END-EVALUATE",
  "           END-IF.",
})
place(9, 20)
local long_option, long_text = render()
assert(long_text:find("<", 1, true) == nil, "plugin must clip the winbar itself, got Neovim truncation: " .. long_text)
assert(long_text:find('WHEN "D"', 1, true), "narrow winbar must keep the innermost part: " .. long_text)
assert(long_text:find("IF STATUS", 1, true), "narrow winbar must keep the enclosing IF: " .. long_text)
assert(long_text:find("END%-EVALUATE") == nil, "narrow winbar must drop waiting closures when there is no room")
assert(vim.api.nvim_strwidth(long_text) <= width, "narrow winbar must fit the window")
assert(long_option:find("…", 1, true), "clipping must be marked explicitly: " .. long_option)
assert(long_option:find("%#CobolBreadcrumbProc#", 1, true), "breadcrumb must use the division highlight")

-- 3. Nothing open at the cursor: no closure indicator.
place(6, 6)
local _, plain = render()
assert(plain:find("PROCEDURE DIVISION", 1, true), "a paragraph-level cursor still shows the chain: " .. plain)
assert(plain:find("⌫", 1, true) == nil, "no waiting closures outside a block: " .. plain)

-- 4. A literal "%" in a label must survive winbar rendering.
attach({
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. PERCENT.",
  "       PROCEDURE DIVISION.",
  "       PERCENT-PARA.",
  "           IF WS-RATE = \"100%\"",
  "               DISPLAY \"X\"",
  "           END-IF.",
})
place(6, 20)
local percent_option, percent_text = render()
assert(percent_option:find('100%%"', 1, true), "the winbar option must escape %: " .. percent_option)
assert(percent_text:find('100%"', 1, true), "a literal % must render once, not be eaten: " .. percent_text)

-- 5. Config can drop the waiting closures from the winbar.
cobol.setup({ show_waiting_closures = false, diagnostics = { enable = false } })
place(6, 20)
local _, without_closures = render()
assert(without_closures:find("⌫", 1, true) == nil, "show_waiting_closures = false must hide the stack")
assert(without_closures:find("PERCENT-PARA", 1, true), "the chain must stay visible without closures: " .. without_closures)

-- 6. Turning the winbar off removes it entirely.
cobol.setup({ show_winbar = false, diagnostics = { enable = false } })
assert(cobol.get_winbar() == "", "get_winbar must return an empty string when show_winbar is false")

print("winbar_spec: OK")
