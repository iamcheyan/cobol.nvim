local cobol = require("cobol")
local navigation = require("cobol.navigation")

local root = vim.fn.tempname() .. "-cobol-workspace"
vim.fn.mkdir(root .. "/copy", "p")
vim.fn.mkdir(root .. "/copy/nested", "p")
vim.fn.mkdir(root .. "/copy-alt", "p")
vim.fn.mkdir(root .. "/src", "p")
vim.fn.writefile({
  "       COPY LEVEL2.",
  "       05 WS-REMOTE-FIELD PIC X(4).",
  "       05 WS-REMOTE-FIELD PIC X(2).",
}, root .. "/copy/REMOTE.CPY")
vim.fn.writefile({ "       05 WS-NESTED-FIELD PIC 9(3)." }, root .. "/copy/nested/LEVEL2.CPY")
vim.fn.writefile({ "       05 WS-REMOTE-FIELD PIC X(9)." }, root .. "/copy-alt/REMOTE.CPY")
vim.fn.writefile({ "       05 WS-ALT-FIELD PIC X(2)." }, root .. "/copy-alt/ALTBOOK.CPY")
vim.fn.writefile({ vim.json.encode({ source_format = "fixed", copybook_paths = { "copy", "copy/nested", "copy-alt" } }) }, root .. "/.cobol.json")

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, root .. "/src/MAIN.COB")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "       DATA DIVISION.",
  "       WORKING-STORAGE SECTION.",
  "           COPY REMOTE REPLACING ==OLD== BY ==NEW==.",
  "       PROCEDURE DIVISION.",
  "           DISPLAY WS-REMOTE-FIELD.",
})
cobol.setup({ copybook_paths = { "only-global" }, diagnostics = { enable = false } })
vim.api.nvim_set_current_buf(buf)

local definitions = navigation.find_definitions("WS-REMOTE-FIELD", buf)
assert(#definitions == 3, "project navigation should include every declaration in referenced Copybooks")
local remote_source_found = false
for _, definition in ipairs(definitions) do
  if definition.filename == root .. "/copy/REMOTE.CPY" and definition.lnum == 2 then
    remote_source_found = true
  end
end
assert(remote_source_found, "Copybook definitions should retain their source file and line")
local nested = navigation.find_definitions("WS-NESTED-FIELD", buf)
assert(#nested == 1 and nested[1].filename == root .. "/copy/nested/LEVEL2.CPY",
  "navigation should recursively follow nested Copy statements")
local duplicates = navigation.find_definitions("WS-REMOTE-FIELD", buf)
assert(#duplicates == 3,
  "navigation should return every same-file declaration for ambiguity selection")
vim.fn.writefile({ "       05 WS-NESTED-FIELD PIC X(8)." }, root .. "/copy/nested/LEVEL2.CPY")
local refreshed = navigation.find_definitions("WS-NESTED-FIELD", buf)
assert(refreshed[1].line:find("X%(8%)"), "Copybook symbol cache should refresh after a file changes")
local nested_buffer = vim.fn.bufadd(root .. "/copy/nested/LEVEL2.CPY")
vim.fn.bufload(nested_buffer)
vim.api.nvim_buf_set_lines(nested_buffer, 0, -1, false, { "       05 WS-NESTED-FIELD PIC X(10)." })
local refreshed_buffer = navigation.find_definitions("WS-NESTED-FIELD", buf)
assert(refreshed_buffer[1].line:find("X%(10%)"),
  "the symbol index should prefer and refresh an edited, unsaved Copybook buffer")
assert(navigation.get_copybook_name_on_line("       COPY REMOTE REPLACING ==OLD== BY ==NEW==.") == "REMOTE",
  "COPY REPLACING should keep the Copybook name separate from replacement text")
assert(navigation.get_copybook_name_on_line("       COPY \"REMOTE.CPY\" REPLACING ==OLD== BY ==NEW==.") == "REMOTE.CPY",
  "quoted Copybook names with extensions should parse independently from REPLACING")
assert(#navigation.find_copybooks("REMOTE", root .. "/src/MAIN.COB", { "copy", "copy-alt" }) == 2,
  "Copybook lookup should expose duplicate matches instead of silently hiding one")
assert(navigation.find_copybook("ALTBOOK", root .. "/src/MAIN.COB") == root .. "/copy-alt/ALTBOOK.CPY",
  "default Copybook lookup should honor .cobol.json paths beyond global plugin settings")
assert(#navigation.find_copybooks("REMOTE", root .. "/src/MAIN.COB", { root .. "/copy-alt" }) == 1,
  "absolute Copybook search paths should work in project profiles")
vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "           DISPLAY WS-NESTED-FIELD." })
vim.api.nvim_win_set_cursor(0, { 5, 23 })
local original_float = navigation.show_float_window
local preview_title, preview_lines
navigation.show_float_window = function(title, content)
  preview_title, preview_lines = title, content
end
navigation.hover_preview()
navigation.show_float_window = original_float
assert(preview_title:find("LEVEL2.CPY", 1, true) and table.concat(preview_lines, "\n"):find("WS-NESTED-FIELD", 1, true),
  "hover should preview the real declaration and source file from a nested Copybook")
vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "           DISPLAY WS-REMOTE-FIELD." })
vim.api.nvim_win_set_cursor(0, { 5, 23 })
local original_select = vim.ui.select
local selection_count
vim.ui.select = function(items, options, callback)
  selection_count = #items
  callback(items[1])
end
navigation.goto_definition()
vim.ui.select = original_select
assert(selection_count == 3 and vim.api.nvim_buf_get_name(0):find("REMOTE.CPY", 1, true),
  "gd should present duplicate definitions and jump to the selected Copybook")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "nx", false)
assert(vim.api.nvim_get_current_buf() == buf, "Ctrl-o should return from a cross-file gd jump to the source")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-i>", true, false, true), "nx", false)
assert(vim.api.nvim_buf_get_name(0):find("REMOTE.CPY", 1, true), "Ctrl-i should replay the cross-file definition jump")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "nx", false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_win_set_cursor(0, { 3, 18 })
selection_count = nil
vim.ui.select = function(items, options, callback)
  selection_count = #items
  callback(items[2])
end
navigation.goto_copybook()
vim.ui.select = original_select
assert(selection_count == 2 and vim.api.nvim_buf_get_name(0) == root .. "/copy-alt/REMOTE.CPY",
  "gf should ask the user to choose when a Copybook name resolves to multiple files")
vim.api.nvim_set_current_buf(buf)

local local_file = root .. "/src/LOCAL.COB"
vim.fn.writefile({ "       PROCEDURE DIVISION.", "       LOCAL-PARA.", "           DISPLAY 'SAVED'." }, local_file)
local local_buf = vim.fn.bufadd(local_file); vim.fn.bufload(local_buf)
vim.api.nvim_buf_set_lines(local_buf, 0, -1, false, {
  "       PROCEDURE DIVISION.",
  "       LOCAL-PARA.",
  "           DISPLAY 'UNSAVED CHANGE'.",
  "           PERFORM LOCAL-PARA.",
})
vim.api.nvim_set_current_buf(local_buf)
vim.api.nvim_win_set_cursor(0, { 4, 22 })
local goto_ok = pcall(navigation.goto_definition)
assert(goto_ok and vim.api.nvim_get_current_buf() == local_buf and vim.bo[local_buf].modified,
  "same-buffer gd should preserve unsaved text without reopening the source file")
assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "same-buffer gd should move to the local paragraph declaration")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "nx", false)
assert(vim.api.nvim_win_get_cursor(0)[1] == 4, "Ctrl-o should also return to the original line after a local gd jump")

vim.fn.delete(root, "rf")
print("navigation_workspace_spec: OK")
