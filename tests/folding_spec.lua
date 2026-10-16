local folding = require("cobol.folding")

vim.cmd([[
  enew
  call setline(1, [
        \ '       IDENTIFICATION DIVISION.',
        \ '       DATA DIVISION.',
        \ '       WORKING-STORAGE SECTION.',
        \ '       01  WS-RECORD.',
        \ '           05  WS-NAME PIC X(10).',
        \ '       PROCEDURE DIVISION.',
        \ '       MAIN-PARA.',
        \ '           DISPLAY WS-NAME.',
        \ '           STOP RUN.',
        \ ])
]])

assert(folding.foldexpr(1):match("^>1$"), "division should start a level 1 fold")
assert(folding.foldexpr(3):match("^>2$"), "section should start a level 2 fold")
assert(folding.foldexpr(4):match("^>3$"), "01 record should start a level 3 fold")
assert(folding.foldexpr(5) == "4", "05 field should be nested below its record")
assert(folding.foldexpr(7):match("^>3$"), "paragraph should start a level 3 fold")
assert(folding.foldexpr(8) == "3", "paragraph body should keep its fold level")

local cobol = require("cobol")
vim.bo.filetype = "cobol"
cobol.setup({ diagnostics = { enable = false } })
assert(vim.wo.foldmethod == "expr", "COBOL buffers should use expression folding")
assert(vim.wo.foldexpr:find("cobol.folding", 1, true), "COBOL foldexpr should use cobol.folding")
assert(vim.wo.foldtext:find("cobol.folding", 1, true), "COBOL foldtext should use cobol.folding")

-- Test foldtext content
vim.v.foldstart = 1
assert(folding.foldtext():find("IDENTIFICATION DIVISION"), "foldtext should display division name")
vim.v.foldstart = 7
assert(folding.foldtext():find("MAIN%-PARA"), "foldtext should display paragraph name")

-- Structure summaries: the point of the AST foldtext is that a folded IF or
-- EVALUATE shows its condition instead of a raw line count.
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. FOLDTEXT.",
  "       PROCEDURE DIVISION.",
  "       MAIN-PARA.",
  "           IF WS-AMOUNT > ZERO",
  "               DISPLAY \"POSITIVE\"",
  "           END-IF.",
  "           EVALUATE TXN-TYPE",
  "             WHEN 1 DISPLAY \"ONE\"",
  "           END-EVALUATE.",
})
vim.v.foldstart = 5
assert(folding.foldtext():find('IF WS-AMOUNT > ZERO', 1, true),
  "foldtext should summarise an IF fold: " .. folding.foldtext())
vim.v.foldstart = 8
assert(folding.foldtext():find("EVALUATE TXN-TYPE", 1, true),
  "foldtext should summarise an EVALUATE fold: " .. folding.foldtext())

-- foldtext ownership: "auto" yields to nvim-ufo when it manages the buffer,
-- "plugin" always installs the COBOL summary, "off" restores the default.
assert(cobol.config.folding.foldtext == "auto", "folding.foldtext should default to auto")

package.loaded["ufo"] = { is_enabled = function() return true end }
vim.wo.foldtext = "foldtext()"
cobol.setup({ folding = { enable = true, foldtext = "auto" }, diagnostics = { enable = false } })
assert(not vim.wo.foldtext:find("cobol.folding", 1, true),
  "auto mode must leave foldtext to nvim-ufo: " .. vim.wo.foldtext)
package.loaded["ufo"] = nil

cobol.setup({ folding = { enable = true, foldtext = "auto" }, diagnostics = { enable = false } })
assert(vim.wo.foldtext:find("cobol.folding", 1, true),
  "auto mode without nvim-ufo must install the COBOL foldtext: " .. vim.wo.foldtext)

cobol.setup({ folding = { enable = true, foldtext = "plugin" }, diagnostics = { enable = false } })
assert(vim.wo.foldtext:find("cobol.folding", 1, true),
  "plugin mode must install the COBOL foldtext: " .. vim.wo.foldtext)

cobol.setup({ folding = { enable = true, foldtext = "off" }, diagnostics = { enable = false } })
assert(not vim.wo.foldtext:find("cobol.folding", 1, true),
  "off mode must restore Neovim's default foldtext: " .. vim.wo.foldtext)

cobol.setup({ diagnostics = { enable = false } })

print("folding_spec: OK")
