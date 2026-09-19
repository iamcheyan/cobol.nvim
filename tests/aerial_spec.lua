local ok_backend, backend = pcall(require, "aerial.backends.cobol")
if not ok_backend then
  print("aerial_spec: SKIP (Aerial is not installed)")
  return
end

require("aerial.config").setup({})

vim.cmd([[enew
call setline(1, [
      \ '       IDENTIFICATION DIVISION.',
      \ '       DATA DIVISION.',
      \ '       WORKING-STORAGE SECTION.',
      \ '       01  WS-RECORD.',
      \ '           05  WS-NAME PIC X(10).',
      \ '       PROCEDURE DIVISION.',
      \ '       MAIN-PARA.',
      \ '           DISPLAY WS-NAME.',
      \ ])
]])
vim.bo.filetype = "cobol"
backend.fetch_symbols_sync(0)
local symbols = require("aerial.data").get(0).items
assert(#symbols == 3, "Aerial backend should expose DATA, record, and procedure roots")
assert(symbols[1].name == "IDENTIFICATION DIVISION")
assert(symbols[2].name == "DATA DIVISION")
assert(symbols[3].name == "PROCEDURE DIVISION")

print("aerial_spec: OK")
