local project = require("cobol.project")

local root = vim.fn.tempname() .. "-cobol-commands"
vim.fn.mkdir(root, "p")
vim.fn.writefile({ "all:", "\t@echo build", "check:", "\t@echo test", "run:", "\t@echo run" }, root .. "/Makefile")

local settings = { root = root, compiler = "cobc", source_format = "fixed", copybook_dirs = { root } }
local build_command, build_kind = project.command(settings, "build", "MAIN.COB", root .. "/main")
assert(vim.deep_equal(build_command, { "make", "all" }), "build should delegate to the Makefile all target")
assert(build_kind == "make", "Makefile commands should be identified as project commands")

local test_command = project.command(settings, "test", "MAIN.COB")
assert(vim.deep_equal(test_command, { "make", "check" }), "test should use the Makefile check target when test is absent")

settings.commands = { run = { "./scripts/run", "--local" } }
local run_command, run_kind = project.command(settings, "run", "MAIN.COB")
assert(vim.deep_equal(run_command, { "./scripts/run", "--local" }) and run_kind == "project", "explicit command arrays should take precedence")

vim.fn.delete(root, "rf")
print("project_commands_spec: OK")
