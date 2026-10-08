local commands = require("cobol.commands")

local entries = commands.parse_output(
  "MAIN.COB:12:8: error: unknown field\nCOPY.CPY:4: warning: obsolete feature\nNOTE.CPY:5: note: check this item\n-:9:2: error: syntax issue\nBuild completed\n",
  "/tmp/cobol-project", "/tmp/cobol-project/UNSAVED.COB"
)
assert(#entries == 4, "build output should become navigable Quickfix entries")
assert(entries[1].filename == "/tmp/cobol-project/MAIN.COB" and entries[1].lnum == 12 and entries[1].col == 8)
assert(entries[1].type == "E" and entries[2].type == "W", "Quickfix entries should preserve compiler severity")
assert(entries[2].filename == "/tmp/cobol-project/COPY.CPY", "relative diagnostics should resolve from project root")
assert(entries[2].type == "W" and entries[3].type == "I", "Quickfix should retain warning and informational severity")
assert(entries[4].filename == "/tmp/cobol-project/UNSAVED.COB" and entries[4].lnum == 9,
  "stdin-based compiler diagnostics should point back to the current source file in Quickfix")

commands.setup()
for _, command in ipairs({ "CobolBuild", "CobolRun", "CobolTest" }) do
  assert(vim.fn.exists(":" .. command) == 2, command .. " should be available as a user command")
end

local root = vim.fn.tempname() .. "-cobol-command-runner"
vim.fn.mkdir(root, "p")
vim.fn.writefile({ vim.json.encode({ commands = { build = { "make", "custom-build" } } }) }, root .. "/.cobol.json")
local source = root .. "/MAIN.COB"
vim.fn.writefile({ "       PROCEDURE DIVISION.", "           GOBACK." }, source)
local cobol = require("cobol")
cobol.setup({ project_root = root, diagnostics = { enable = false } })
local buf = vim.fn.bufadd(source)
vim.fn.bufload(buf)
vim.api.nvim_set_current_buf(buf)
local original_system = vim.system
local captured_command, captured_options
vim.system = function(command_args, options)
  captured_command, captured_options = command_args, options
  return { kill = function() end }
end
commands.run("build", buf)
vim.system = original_system
assert(vim.deep_equal(captured_command, { "make", "custom-build" }), "build should execute the configured project command")
assert(captured_options.cwd == root, "project commands should run from the discovered root")
vim.fn.delete(root, "rf")

local no_run_root = vim.fn.tempname() .. "-cobol-no-project-run"
vim.fn.mkdir(no_run_root, "p")
vim.fn.writefile({ "build:" }, no_run_root .. "/Makefile")
vim.fn.writefile({ vim.json.encode({ commands = { build = { "make", "build" } } }) }, no_run_root .. "/.cobol.json")
local no_run_source = no_run_root .. "/MAIN.COB"
vim.fn.writefile({ "       PROCEDURE DIVISION.", "           GOBACK." }, no_run_source)
local no_run_buf = vim.fn.bufadd(no_run_source); vim.fn.bufload(no_run_buf)
vim.fn.executable = function() return 1 end
local spawn_count = 0
vim.system = function() spawn_count = spawn_count + 1; return { kill = function() end } end
local no_run_result = commands.run("run", no_run_buf)
vim.fn.executable, vim.system = original_executable, original_system
assert(no_run_result == false and spawn_count == 0,
  "a project with build rules but no run target should ask for a project run command instead of guessing")
vim.fn.delete(no_run_root, "rf")

print("commands_spec: OK")
