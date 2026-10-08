-- blink.cmp source adapter for cobol.nvim.

local completion = require("cobol.completion")
local source = {}

local kind = vim.lsp.protocol.CompletionItemKind
local kind_map = {
  Keyword = kind.Keyword,
  Field = kind.Field,
  Record = kind.Struct,
  Condition = kind.EnumMember,
  Section = kind.Method,
  Paragraph = kind.Function,
  Copybook = kind.File,
  Rename = kind.Field,
  Constant = kind.Constant,
}

function source.new(opts)
  return setmetatable({ opts = opts or {} }, { __index = source })
end

function source:enabled()
  return vim.tbl_contains({ "cobol", "cbl", "cob" }, vim.bo.filetype)
end

function source:get_trigger_characters()
  return { "-", "_", "." }
end

function source:get_completions(ctx, callback)
  if not self:enabled() then
    callback({ items = {} })
    return
  end

  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local completion_opts = {}
  local ok_cobol, cobol = pcall(require, "cobol")
  local ok_navigation, navigation = pcall(require, "cobol.navigation")
  if ok_cobol and ok_navigation then
    local current_file = vim.api.nvim_buf_get_name(bufnr)
    completion_opts.resolve_copybook = function(name)
      local path = navigation.find_copybook(name, current_file)
      if not path then return nil end
      return vim.fn.readfile(path)
    end
  end
  local items = completion.complete(lines, "", completion_opts)
  local plain_text = vim.lsp.protocol.InsertTextFormat.PlainText
  local cursor = ctx.cursor
  local line = ctx.line or lines[cursor and cursor[1] or 1] or ""
  local cursor_col = cursor and cursor[2]
  if cursor_col == nil then cursor_col = #line end
  local before_cursor = line:sub(1, cursor_col):upper()
  -- Blink guesses the replacement range from the current word. For a phrase
  -- such as `PIC X`, that range starts after the space, so inserting the full
  -- `PIC X(...)` snippet would leave the original `PIC` behind.
  local pic_start = before_cursor:match("()PIC%s*$") or before_cursor:match("()PIC%s+[%w%(]*$")

  for _, item in ipairs(items) do
    local original_kind = item.kind
    item.kind = kind_map[original_kind] or kind.Text
    item.insertText = item.insertText or item.label
    item.insertTextFormat = item.insertTextFormat
      or (original_kind == "Snippet" and vim.lsp.protocol.InsertTextFormat.Snippet or plain_text)
    if original_kind == "Snippet" and item.label:match("^PIC ") and pic_start then
      local row = cursor and cursor[1] or vim.api.nvim_win_get_cursor(0)[1]
      item.textEdit = {
        range = {
          start = { line = row - 1, character = pic_start - 1 },
          ["end"] = { line = row - 1, character = cursor_col },
        },
        newText = item.insertText,
      }
    end
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

return source
