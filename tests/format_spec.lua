local formatter = require("cobol.formatter")

local line = "       move ws-name to ws-target."
assert(formatter.format_line(line) == "       MOVE ws-name TO ws-target.", "keywords should be uppercased")

local protected = "       display 'move if' *> move if"
assert(
  formatter.format_line(protected) == "       DISPLAY 'move if' *> move if",
  "strings and comments must remain unchanged"
)

local variable = "       move-count = 1"
assert(formatter.format_line(variable) == variable, "identifiers containing keywords must remain unchanged")

vim.cmd([[enew
call setline(1, ['       move a to b.', "       if a = 1 end-if."])
]])
local changed = formatter.format_range(0, 1, 2)
assert(changed == 2, "format_range should report changed lines")
assert(vim.fn.getline(1) == "       MOVE a TO b.")
assert(vim.fn.getline(2) == "       IF a = 1 END-IF.")

print("format_spec: OK")
