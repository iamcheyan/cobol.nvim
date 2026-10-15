-- Tree-sitter-backed structural navigation for COBOL.
-- AST features deliberately have no regex parser fallback.
local M = {}
local palette = { "#61afef", "#e5c07b", "#e06c75", "#98c379", "#c678dd", "#56b6c2" }

local kinds = {
  if_header = { name = "IF", ending = "END-IF", end_node = "END_IF" },
  evaluate_header = { name = "EVALUATE", ending = "END-EVALUATE", end_node = "END_EVALUATE" },
  perform_statement_loop = { name = "PERFORM", ending = "END-PERFORM", end_node = "END_PERFORM" },
  search_statement = { name = "SEARCH", ending = "END-SEARCH", end_node = "END_SEARCH" },
  read_statement = { name = "READ", ending = "END-READ", end_node = "END_READ" },
  write_statement = { name = "WRITE", ending = "END-WRITE", end_node = "END_WRITE" },
  rewrite_statement = { name = "REWRITE", ending = "END-REWRITE", end_node = "END_REWRITE" },
  delete_statement = { name = "DELETE", ending = "END-DELETE", end_node = "END_DELETE" },
  start_statement = { name = "START", ending = "END-START", end_node = "END_START" },
  string_statement = { name = "STRING", ending = "END-STRING", end_node = "END_STRING" },
  unstring_statement = { name = "UNSTRING", ending = "END-UNSTRING", end_node = "END_UNSTRING" },
}

local function is_cobol(bufnr)
  local ft = vim.bo[bufnr or 0].filetype
  return ft == "cobol" or ft == "cbl" or ft == "cob"
end

function M.parser(bufnr)
  bufnr = bufnr or 0
  if not is_cobol(bufnr) or not vim.treesitter or not vim.treesitter.get_parser then return nil end
  local paths = vim.api.nvim_get_runtime_file("parser/cobol.so", false)
  local opts = #paths > 0 and { path = paths[1], symbol_name = "COBOL" } or nil
  local ok_add = pcall(vim.treesitter.language.add, "cobol", opts)
  if not ok_add then ok_add = pcall(vim.treesitter.language.add, "cobol") end
  if not ok_add then return nil end
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "cobol", { error = false })
  if not ok or not parser then return nil end
  local ok_parse, trees = pcall(parser.parse, parser)
  if not ok_parse or not trees or not trees[1] then return nil end
  return trees[1]:root()
end

local function node_text(node, bufnr)
  local ok, value = pcall(vim.treesitter.get_node_text, node, bufnr)
  return ok and value:gsub("%s+", " ") or node:type()
end

function M.structures(bufnr)
  bufnr = bufnr or 0
  local root = M.parser(bufnr)
  if not root then return {} end
  local result, pending = {}, {}
  local function visit(node)
    local spec = kinds[node:type()]
    if spec then
      local sr, sc, er, ec = node:range()
      local item = { node = node, name = spec.name, ending = spec.ending, end_node_type = spec.end_node,
        label = node_text(node, bufnr), start_row = sr, start_col = sc, end_row = er, end_col = ec }
      result[#result + 1] = item
      pending[#pending + 1] = item
    elseif node:type():match("^END_") then
      local item
      for i = #pending, 1, -1 do
        if pending[i].end_node_type == node:type() then item = table.remove(pending, i); break end
      end
      if item then
        local sr, sc = node:start()
        local er, ec = node:end_()
        item.close_node, item.close_row, item.close_col = node, sr, sc
        item.end_row, item.end_col = er, ec
        item.depth = #pending + 1
      end
    end
    for child in node:iter_children() do visit(child) end
  end
  visit(root)
  for _, item in ipairs(result) do if not item.depth then item.depth = 1 end end
  table.sort(result, function(a, b)
    if a.start_row == b.start_row then return a.start_col < b.start_col end
    return a.start_row < b.start_row
  end)
  return result
end

function M.at_cursor(bufnr, row, col)
  bufnr = bufnr or 0
  if row == nil then
    local pos = vim.api.nvim_win_get_cursor(0)
    row, col = pos[1] - 1, pos[2]
  end
  col = col or 0
  local active = {}
  for _, item in ipairs(M.structures(bufnr)) do
    local after_open = row > item.start_row or (row == item.start_row and col >= item.start_col)
    local before_close = item.close_row and (row < item.close_row or (row == item.close_row and col <= item.end_col))
    if after_open and before_close then active[#active + 1] = item end
  end
  table.sort(active, function(a, b) return a.depth > b.depth end)
  return active
end

function M.closure_stack(bufnr, row, col)
  local out = {}
  for _, item in ipairs(M.at_cursor(bufnr, row, col)) do out[#out + 1] = item.ending .. " (" .. item.label .. ")" end
  return out
end

function M.textobject(bufnr, row, col, kind, inner)
  for _, item in ipairs(M.at_cursor(bufnr, row, col)) do
    if item.name == kind then
      if inner then
        local start_line = vim.api.nvim_buf_get_lines(bufnr, item.start_row, item.start_row + 1, false)[1] or ""
        local keyword = start_line:find(item.name, item.start_col + 1, true)
        local start_col = keyword and keyword - 1 + #item.name or item.start_col
        return { item.start_row, start_col, item.close_row, item.close_col }
      end
      return { item.start_row, item.start_col, item.close_row, item.end_col }
    end
  end
end

function M.jump_match(bufnr, row, col)
  local item = M.at_cursor(bufnr, row, col)[1]
  if not item then return nil end
  if row == item.start_row and col <= item.start_col + #item.name then return { item.close_row, item.close_col } end
  return { item.start_row, item.start_col }
end

function M.aerial_items(bufnr)
  local items = {}
  for _, item in ipairs(M.structures(bufnr or 0)) do
    items[#items + 1] = { name = item.label, kind = "Function", lnum = item.start_row + 1,
      col = item.start_col, end_lnum = item.end_row + 1, end_col = item.end_col, children = {} }
  end
  return items
end

function M.setup_highlights()
  for i, color in ipairs(palette) do
    vim.api.nvim_set_hl(0, "CobolStructure" .. i, { fg = color, bold = true, default = true })
  end
  vim.api.nvim_set_hl(0, "CobolWaitingClosure", { fg = "#e5c07b", default = true })
end

function M.update(bufnr, winid)
  bufnr, winid = bufnr or 0, winid or vim.api.nvim_get_current_win()
  if not M.parser(bufnr) then return nil end
  local ns = vim.api.nvim_create_namespace("cobol_ast_navigation")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local active = M.at_cursor(bufnr, cursor[1] - 1, cursor[2])
  for _, item in ipairs(active) do
    local hl = "CobolStructure" .. ((item.depth - 1) % #palette + 1)
    vim.api.nvim_buf_set_extmark(bufnr, ns, item.start_row, item.start_col, {
      end_row = item.start_row, end_col = math.min(item.start_col + #item.name, item.end_col), hl_group = hl, priority = 140,
    })
    vim.api.nvim_buf_set_extmark(bufnr, ns, item.close_row, item.close_col, {
      end_row = item.close_row, end_col = item.end_col, hl_group = hl, priority = 140,
    })
  end
  local ancestors, node = {}, vim.treesitter.get_node({ bufnr = bufnr, pos = { cursor[1] - 1, cursor[2] } })
  while node do
    local kind = node:type()
    if kind == "procedure_division" or kind == "section_header" or kind == "paragraph_header" then
      table.insert(ancestors, 1, node_text(node, bufnr))
    end
    node = node:parent()
  end
  for i = #active, 1, -1 do ancestors[#ancestors + 1] = active[i].label end
  local waiting = M.closure_stack(bufnr, cursor[1] - 1, cursor[2])
  vim.w[winid].cobol_ast_breadcrumb = table.concat(ancestors, " > ")
  vim.w[winid].cobol_waiting_closures = waiting
  return { breadcrumb = vim.w[winid].cobol_ast_breadcrumb, waiting = waiting, active = active }
end

return M
