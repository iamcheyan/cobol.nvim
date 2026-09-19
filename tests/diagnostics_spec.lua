local diagnostics = require("cobol.diagnostics")

local detailed = assert(diagnostics.parse_line("main.cbl:5:7: error: invalid syntax"))
assert(detailed.file == "main.cbl" and detailed.lnum == 5 and detailed.col == 7)
assert(detailed.severity == "error" and detailed.message == "invalid syntax")
local without_col = assert(diagnostics.parse_line("SHARED.CPY:3: warning: missing period"))
assert(without_col.file == "SHARED.CPY" and without_col.lnum == 3 and without_col.col == nil)

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/main.cbl")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "       DISPLAY X." })
vim.diagnostic.set(diagnostics.ns, buf, {
  { lnum = 0, col = 0, message = "newer result", severity = vim.diagnostic.severity.INFO },
})

diagnostics.process_output(buf, { stderr = "-:1:1: error: stale result" }, { "       DISPLAY X." }, vim.fn.getcwd(), {
  generation = 1,
  current_generation = function()
    return 2
  end,
})

local current = vim.diagnostic.get(buf, { namespace = diagnostics.ns })
assert(#current == 1 and current[1].message == "newer result", "stale diagnostics must be ignored")

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local copybook = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(copybook, root .. "/SHARED.CPY")
vim.api.nvim_buf_set_lines(copybook, 0, -1, false, { "       01  BROKEN." })
diagnostics.process_output(
  buf,
  { stderr = "./SHARED.CPY:1:1: error: invalid copybook" },
  { "       COPY SHARED.CPY." },
  root,
  {}
)
local copybook_diags = vim.diagnostic.get(copybook, { namespace = diagnostics.ns })
assert(#copybook_diags == 1, "relative Copybook diagnostics should map to the open Copybook buffer")

print("diagnostics_spec: OK")
