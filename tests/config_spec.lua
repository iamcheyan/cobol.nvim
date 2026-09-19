local cobol = require("cobol")
local navigation = require("cobol.navigation")

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.writefile({ "       01  COPY-FIELD PIC X." }, root .. "/SHARED.CPY")

cobol.setup({
  project_root = root,
  copybook_paths = { "." },
  diagnostics = { enable = false },
})

local found = navigation.find_copybook("SHARED.CPY", root .. "/src/main.cbl")
assert(found == root .. "/SHARED.CPY", "navigation should resolve copybooks from project_root")

print("config_spec: OK")
