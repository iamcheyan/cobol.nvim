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

local src_dir = root .. "/src"
vim.fn.mkdir(src_dir, "p")
cobol.setup({ project_root = root .. "/stale-project-root" })
local resolved_root = cobol.get_project_root(0, src_dir .. "/main.cbl")
assert(resolved_root == src_dir, "a stale project_root should fall back to the existing COBOL file directory")
cobol.setup({ project_root = root, copybook_paths = { "." }, diagnostics = { enable = false } })

local lint_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(lint_buf, src_dir .. "/main.cbl")
vim.api.nvim_buf_set_lines(lint_buf, 0, -1, false, { "       DISPLAY 'TEST'." })
local diagnostics = require("cobol.diagnostics")
local original_executable, original_system = vim.fn.executable, vim.system
local captured_cwd
vim.fn.executable = function() return 1 end
vim.system = function(_, options)
  captured_cwd = options.cwd
  return { kill = function() end }
end
cobol.setup({ project_root = root .. "/stale-project-root", diagnostics = { enable = true } })
local lint_ok, lint_result = pcall(diagnostics.lint, lint_buf)
vim.fn.executable, vim.system = original_executable, original_system
assert(lint_ok and lint_result == true, "diagnostics should spawn after falling back from a stale project_root")
assert(captured_cwd == src_dir, "diagnostics cwd should fall back to the existing COBOL file directory")
diagnostics.clear(lint_buf)

vim.fn.executable = function() return 1 end
vim.system = function() error("simulated spawn failure") end
local spawn_ok, spawn_result, spawn_reason = pcall(diagnostics.lint, lint_buf)
vim.fn.executable, vim.system = original_executable, original_system
assert(spawn_ok, "a synchronous vim.system spawn failure should not escape diagnostics.lint")
assert(spawn_result == false and spawn_reason == "spawn_failed", "spawn failure should return a stable error result")
cobol.setup({ project_root = root, copybook_paths = { "." }, diagnostics = { enable = false } })

local duplicate_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(duplicate_buf, 0, -1, false, {
  "       PROCEDURE DIVISION.",
  "       SHARED-PARA.",
  "           DISPLAY 'first'.",
  "       OTHER-PARA.",
  "           PERFORM SHARED-PARA.",
  "       SHARED-PARA.",
  "           DISPLAY 'second'.",
})
vim.api.nvim_set_current_buf(duplicate_buf)
vim.api.nvim_win_set_cursor(0, { 5, 10 })
local duplicate = navigation.find_definition("SHARED-PARA", duplicate_buf)
assert(duplicate and duplicate.lnum == 6, "same-name definitions should prefer the nearest definition")

local free_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(free_buf, 0, -1, false, { "IDENTIFICATION DIVISION." })
assert(cobol.detect_format(free_buf) == "free", "free-format source should be detected")
vim.api.nvim_set_current_buf(free_buf)
cobol.toggle_comment(1, 1)
assert(vim.api.nvim_buf_get_lines(free_buf, 0, 1, false)[1] == "*> IDENTIFICATION DIVISION.", "free-format comments should use *>")
assert(cobol.detect_format(free_buf) == "free", "a commented free-format buffer should remain detectable")
cobol.toggle_comment(1, 1)
assert(vim.api.nvim_buf_get_lines(free_buf, 0, 1, false)[1] == "IDENTIFICATION DIVISION.", "free-format comments should toggle off cleanly")

local cobol_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(cobol_buf, 0, -1, false, {
  "       DISPLAY 'TEST'.",
  "       01 WS-OUT-TOTAL",
  "      *01 WS-RETURN-CODE",
  "       88 EOF-YES",
  "      *88 EOF-NO",
})
vim.bo[cobol_buf].filetype = "cobol"
vim.api.nvim_set_current_buf(cobol_buf)
cobol.attach(cobol_buf)
assert(vim.bo[cobol_buf].indentexpr:match("cobol%.indent"), "COBOL buffers should use the fixed-format indent expression")
local gcc_map = vim.fn.maparg("gcc", "n", false, true)
assert(gcc_map.buffer == 1, "COBOL gcc mapping should be buffer-local")
assert(gcc_map.desc == "COBOL: Toggle Col 7 Comment (*)", "COBOL gcc should use fixed-format comments")
local match_patterns = {}
for _, match in ipairs(vim.fn.getmatches()) do
  if match.group == "CobolLevel01" or match.group == "CobolLevel88" then
    match_patterns[match.group] = match.pattern
  end
end
assert(vim.fn.matchstr("       01 WS-OUT-TOTAL", match_patterns.CobolLevel01) == "01", "01 levels should stay highlighted in code")
assert(vim.fn.matchstr("      *01 WS-RETURN-CODE", match_patterns.CobolLevel01) == "", "commented 01 levels should not override comment color")
assert(vim.fn.matchstr("       88 EOF-YES", match_patterns.CobolLevel88) == "88", "88 levels should stay highlighted in code")
assert(vim.fn.matchstr("      *88 EOF-NO", match_patterns.CobolLevel88) == "", "commented 88 levels should not override comment color")

print("config_spec: OK")
