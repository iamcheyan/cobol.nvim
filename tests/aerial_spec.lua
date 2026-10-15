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
      \ '       INPUT-SECTION SECTION.',
      \ '       VALIDATE-INPUT.',
      \ '           IF STATUS = "A"',
      \ '               EVALUATE TXN-TYPE',
      \ '                   WHEN "D"',
      \ '                       CALL "CUSM001"',
      \ '               END-EVALUATE',
      \ '           END-IF.',
      \ '       UPDATE-ACCOUNT.',
      \ '           READ ACCOUNT-FILE',
      \ '           REWRITE ACCOUNT-REC',
      \ '           WRITE AUDIT-LOG',
      \ '           PERFORM UNTIL EOF-REC',
      \ '               DISPLAY "LOOP"',
      \ '           END-PERFORM.',
      \ ])
]])
vim.bo.filetype = "cobol"
backend.fetch_symbols_sync(0)
local symbols = require("aerial.data").get(0).items
assert(#symbols == 3, "Aerial backend should expose IDENTIFICATION, DATA, and PROCEDURE roots")
assert(symbols[1].name == "IDENTIFICATION DIVISION")
assert(symbols[2].name == "DATA DIVISION")
assert(symbols[3].name == "PROCEDURE DIVISION")

local proc = symbols[3]
assert(proc.children and #proc.children > 0, "PROCEDURE DIVISION must have children")

-- Find INPUT-SECTION
local input_sec = nil
for _, child in ipairs(proc.children) do
  if child.name == "INPUT-SECTION" then
    input_sec = child
    break
  end
end
assert(input_sec, "INPUT-SECTION must be present without 'SECTION' suffix")

-- Find VALIDATE-INPUT under INPUT-SECTION
local val_para = nil
for _, child in ipairs(input_sec.children or {}) do
  if child.name == "VALIDATE-INPUT" then
    val_para = child
    break
  end
end
assert(val_para, "VALIDATE-INPUT must be a child of INPUT-SECTION")

-- Find IF STATUS under VALIDATE-INPUT
local if_node = nil
for _, child in ipairs(val_para.children or {}) do
  if child.name:find("IF STATUS") then
    if_node = child
    break
  end
end
assert(if_node, "IF STATUS must be nested under VALIDATE-INPUT")

-- Find EVALUATE TXN-TYPE under IF STATUS
local eval_node = nil
for _, child in ipairs(if_node.children or {}) do
  if child.name:find("EVALUATE TXN%-TYPE") then
    eval_node = child
    break
  end
end
assert(eval_node, "EVALUATE TXN-TYPE must be nested under IF STATUS")

-- Find WHEN "D" under EVALUATE
local when_node = nil
for _, child in ipairs(eval_node.children or {}) do
  if child.name:find('WHEN "D"') then
    when_node = child
    break
  end
end
assert(when_node, 'WHEN "D" must be nested under EVALUATE')

-- Find CALL CUSM001 under WHEN "D" or EVALUATE
local call_node = nil
local candidates = #when_node.children > 0 and when_node.children or eval_node.children
for _, child in ipairs(candidates or {}) do
  if child.name:find("CALL CUSM001") then
    call_node = child
    break
  end
end
assert(call_node, "CALL CUSM001 must be present with quotes removed")

-- Find UPDATE-ACCOUNT under INPUT-SECTION or PROCEDURE DIVISION
local update_para = nil
for _, child in ipairs(input_sec.children or proc.children) do
  if child.name == "UPDATE-ACCOUNT" then
    update_para = child
    break
  end
end
assert(update_para, "UPDATE-ACCOUNT must be present")

-- Check operations under UPDATE-ACCOUNT
local child_names = {}
for _, child in ipairs(update_para.children or {}) do
  child_names[child.name] = true
end

assert(child_names["READ ACCOUNT-FILE"], "READ ACCOUNT-FILE must be present under UPDATE-ACCOUNT")
assert(child_names["REWRITE ACCOUNT-REC"], "REWRITE ACCOUNT-REC must be present under UPDATE-ACCOUNT")
assert(child_names["WRITE AUDIT-LOG"], "WRITE AUDIT-LOG must be present under UPDATE-ACCOUNT")
assert(child_names["PERFORM UNTIL EOF-REC"], "PERFORM UNTIL EOF-REC must be present under UPDATE-ACCOUNT")

print("aerial_spec: OK")
