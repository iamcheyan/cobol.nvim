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

print("folding_spec: OK")
