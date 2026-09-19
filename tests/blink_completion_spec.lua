local source = require("cobol.completion.blink")

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "       PROCEDURE DIVISION.",
  "       1000-INITIALIZE.",
})
vim.bo[bufnr].filetype = "cobol"
vim.api.nvim_set_current_buf(bufnr)

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

vim.bo[bufnr].filetype = "lua"
assert(not provider:enabled(), "blink source should stay disabled outside COBOL")

print("blink_completion_spec: OK")
