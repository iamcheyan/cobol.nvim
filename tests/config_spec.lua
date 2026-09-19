local cobol = require("cobol")
local navigation = require("cobol.navigation")

local root = vim.fn.tempname() .. " cobol project"
vim.fn.mkdir(root, "p")
vim.fn.writefile({ "       01  COPY-FIELD PIC X." }, root .. "/SHARED.CPY")

cobol.setup({
  project_root = root,
  copybook_paths = { "." },
  diagnostics = { enable = false },
})

local found = navigation.find_copybook("SHARED.CPY", root .. "/src/main.cbl")
assert(found == root .. "/SHARED.CPY", "navigation should resolve copybooks from project_root")
assert(navigation.get_copybook_name_on_line("       COPY SHARED REPLACING ==A== BY ==B==.") == "SHARED")

local free_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(free_buf, 0, -1, false, { "IDENTIFICATION DIVISION." })
assert(cobol.detect_format(free_buf) == "free", "free-format source should be detected")

print("config_spec: OK")
