local diagnostics = require("cobol.diagnostics")

local detailed = assert(diagnostics.parse_line("main.cbl:5:7: error: invalid syntax"))
assert(detailed.file == "main.cbl" and detailed.lnum == 5 and detailed.col == 7)
assert(detailed.severity == "error" and detailed.message == "invalid syntax")
local without_col = assert(diagnostics.parse_line("SHARED.CPY:3: warning: missing period"))
assert(without_col.file == "SHARED.CPY" and without_col.lnum == 3 and without_col.col == nil)
local windows_path = assert(diagnostics.parse_line("C:/work/MAIN.COB:8:2: note: check this clause"))
assert(windows_path.file == "C:/work/MAIN.COB" and windows_path.severity == "note",
  "diagnostics should parse drive-letter paths and informational severities")

local context = diagnostics.parse_line("main.cbl: in paragraph 'MAIN-PARA':")
assert(context == nil, "context-only compiler lines should not become diagnostics")

local invalid, reason = diagnostics.lint(999999, { interactive = false })
assert(invalid == false and reason == "invalid_buffer", "invalid buffers should fail explicitly")

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
vim.diagnostic.enable(false, { namespace = diagnostics.ns, bufnr = buf })
assert(diagnostics.is_enabled(buf) == false, "diagnostics disabled state should be detectable")
vim.diagnostic.enable(true, { namespace = diagnostics.ns, bufnr = buf })

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.writefile({ "       01  BROKEN." }, root .. "/SHARED.CPY")
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
local copy_origin = vim.diagnostic.get(buf, { namespace = diagnostics.ns })
assert(#copy_origin == 1 and copy_origin[1].lnum == 0 and copy_origin[1].message:find("SHARED.CPY", 1, true),
  "Copybook diagnostics should also identify the originating COPY line in the main source")
diagnostics.process_output(buf, { stderr = "-:1:200: error: far column" }, { "DISPLAY X." }, root, {})
local clamped = vim.diagnostic.get(buf, { namespace = diagnostics.ns })
assert(#clamped == 1 and clamped[1].col <= clamped[1].end_col,
  "diagnostic ranges should stay valid when compiler columns exceed the source line")

local cobol = require("cobol")
vim.fn.writefile({ vim.json.encode({
  source_format = "fixed",
  dialect = "ibm",
  compiler = "profile-cobc",
  copybook_paths = { "copy", "./copy" },
  compiler_args = { "-DPROJECT" },
}) }, root .. "/.cobol.json")
local original_executable, original_system = vim.fn.executable, vim.system
local captured_command
vim.fn.executable = function(command) return command == "profile-cobc" and 1 or 0 end
vim.system = function(command)
  captured_command = command
  return { kill = function() end }
end
cobol.setup({ project_root = root, diagnostics = { enable = true } })
local profile_lint_ok, profile_lint_result = pcall(diagnostics.lint, buf)
vim.fn.executable, vim.system = original_executable, original_system
assert(profile_lint_ok and profile_lint_result == true, "diagnostics should accept the project compiler profile")
assert(captured_command[1] == "profile-cobc", "diagnostics should use the project compiler")
assert(vim.tbl_contains(captured_command, "-std=ibm"), "diagnostics should use the project dialect")
assert(vim.tbl_contains(captured_command, "-fixed"), "diagnostics should use the fixed source format")
assert(vim.tbl_contains(captured_command, "-DPROJECT"), "diagnostics should include project compiler arguments")
local include_dirs = {}
for i, arg in ipairs(captured_command) do
  if arg == "-I" then include_dirs[#include_dirs + 1] = captured_command[i + 1] end
end
assert(#include_dirs == 2 and include_dirs[2] == root .. "/copy", "diagnostics should deduplicate and resolve project Copybook paths")
diagnostics.clear(buf)

vim.api.nvim_buf_delete(copybook, { force = true })
vim.fn.delete(root .. "/SHARED.CPY")
vim.fn.mkdir(root .. "/copy", "p")
vim.fn.writefile({ "       05 WS-BROKEN PIC X." }, root .. "/copy/SHARED.CPY")
local wrong_copybook = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(wrong_copybook, vim.fn.tempname() .. "/SHARED.CPY")
vim.api.nvim_buf_set_lines(wrong_copybook, 0, -1, false, { "       05 WS-WRONG PIC X." })
local actual_copybook = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(actual_copybook, root .. "/copy/SHARED.CPY")
vim.api.nvim_buf_set_lines(actual_copybook, 0, -1, false, { "       05 WS-BROKEN PIC X." })
local copy_source = { "       DATA DIVISION.", "       01 REC.", "           COPY SHARED." }
vim.api.nvim_buf_set_lines(buf, 0, -1, false, copy_source)
diagnostics.process_output(buf, { stderr = "SHARED.CPY:1: warning: invalid copybook field" },
  copy_source, root, {})
assert(#vim.diagnostic.get(actual_copybook, { namespace = diagnostics.ns }) == 1,
  "a basename-only compiler path should resolve through configured Copybook directories")
assert(#vim.diagnostic.get(wrong_copybook, { namespace = diagnostics.ns }) == 0,
  "duplicate Copybook basenames must not receive diagnostics for another project file")
local source_copy_diags = vim.diagnostic.get(buf, { namespace = diagnostics.ns })
assert(#source_copy_diags == 1 and source_copy_diags[1].lnum == 2,
  "Copybook diagnostics should map back to the matching COPY statement")
diagnostics.process_output(buf, { stderr = "" }, copy_source, root, {})
assert(#vim.diagnostic.get(actual_copybook, { namespace = diagnostics.ns }) == 0,
  "a clean rebuild should clear stale diagnostics from previously referenced Copybooks")
diagnostics.process_output(buf, { stderr = "/external/UNRELATED.CPY:2: error: unrelated source" },
  { "       DISPLAY X." }, root, {})
assert(#vim.diagnostic.get(buf, { namespace = diagnostics.ns }) == 0,
  "unrelated Copybook diagnostics must not be falsely pinned to line 1 of the main file")

print("diagnostics_spec: OK")
