local source = require("cobol.completion.blink")

local root = vim.fn.tempname() .. "-blink-copybook-profile"
vim.fn.mkdir(root .. "/profile-copy", "p")
vim.fn.writefile({ "       05 WS-PROFILE-FIELD PIC X." }, root .. "/profile-copy/ALTBOOK.CPY")
vim.fn.writefile({ vim.json.encode({ source_format = "fixed", copybook_paths = { "profile-copy" } }) },
  root .. "/.cobol.json")
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, root .. "/MAIN.COB")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "       PROCEDURE DIVISION.",
  "           COPY ALTBOOK.",
})
vim.bo[bufnr].filetype = "cobol"
vim.api.nvim_set_current_buf(bufnr)
require("cobol").setup({ project_root = root, copybook_paths = { "global-only" }, diagnostics = { enable = false } })

local provider = source.new({})
assert(provider:enabled(), "blink source should enable for COBOL buffers")

local response
provider:get_completions({ bufnr = bufnr, line_before_cursor = "       PER" }, function(items)
  response = items
end)
assert(response and #response.items > 0, "blink source should return completion items")
local found_perform = false
local found_if_snippet = false
for _, item in ipairs(response.items) do
  if item.label == "PERFORM" then found_perform = true end
  if item.label == "IF ... END-IF" then
    found_if_snippet = found_if_snippet
      or item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet
  end
end
assert(found_perform, "blink source should expose PERFORM")
assert(found_if_snippet, "blink source should preserve snippet insert text format")
local found_profile_field = false
for _, item in ipairs(response.items) do
  if item.label == "WS-PROFILE-FIELD" then found_profile_field = true end
end
assert(found_profile_field, "completion should resolve Copybooks through .cobol.json paths")

local pic_line = "       05 FMT-PAGE PIC X"
local pic_response
provider:get_completions({
  bufnr = bufnr,
  line = pic_line,
  cursor = { 1, #pic_line },
}, function(items)
  pic_response = items
end)
local pic_item
for _, item in ipairs(pic_response.items) do
  if item.label == "PIC X(n)" then pic_item = item; break end
end
assert(pic_item and pic_item.textEdit, "PIC completion should provide an explicit replacement range")
assert(pic_item.textEdit.range.start.character == pic_line:find("PIC", 1, true) - 1,
  "PIC completion should replace the full PIC clause prefix, not only X")
assert(pic_item.textEdit.newText == pic_item.insertText, "PIC completion should preserve its snippet text edit")

vim.bo[bufnr].filetype = "lua"
assert(not provider:enabled(), "blink source should stay disabled outside COBOL")

vim.fn.delete(root, "rf")
print("blink_completion_spec: OK")
