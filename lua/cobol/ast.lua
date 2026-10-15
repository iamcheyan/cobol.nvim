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
  xml_parse_statement = { name = "XML PARSE", ending = "END-XML", end_node = "END_XML" },
  json_parse_statement = { name = "JSON PARSE", ending = "END-JSON", end_node = "END_JSON" },
  exec_sql_statement = { name = "EXEC SQL", ending = "END-EXEC", end_node = "END_EXEC" },
  class_id_header = { name = "CLASS-ID", ending = "END CLASS", end_node = "END_CLASS" },
  method_id_header = { name = "METHOD-ID", ending = "END METHOD", end_node = "END_METHOD" },
  factory_header = { name = "FACTORY", ending = "END FACTORY", end_node = "END_FACTORY" },
  object_header = { name = "OBJECT", ending = "END OBJECT", end_node = "END_OBJECT" },
}
M.kinds = kinds

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

local function clean_label(text)
  text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  text = text:gsub("%.$", "")
  return text
end

local function node_text(node, bufnr)
  local ok, value = pcall(vim.treesitter.get_node_text, node, bufnr)
  return ok and clean_label(value) or node:type()
end

local function format_structure_label(node, bufnr, default_name)
  local raw = node_text(node, bufnr)
  if default_name == "CALL" then
    local target = raw:match('^CALL%s+["\']?([%w%-_]+)["\']?')
    return target and ("CALL " .. target) or raw
  elseif default_name == "WHEN" then
    local clause = raw:match("^(WHEN%s+.-)%s+DISPLAY") or raw:match("^(WHEN%s+.-)%s+MOVE") or raw
    return clean_label(clause)
  elseif default_name == "EXEC SQL" then
    local upper = raw:upper()
    local act = upper:match("EXEC%s+SQL%s+([A-Z]+)") or "EXEC"
    for _, known in ipairs({ "SELECT", "INSERT", "UPDATE", "DELETE", "CURSOR", "FETCH", "OPEN", "CLOSE", "COMMIT", "ROLLBACK" }) do
      if act:find(known, 1, true) then
        act = known
        break
      end
    end
    return (act == "SELECT" or act == "UPDATE" or act == "INSERT" or act == "DELETE")
      and ("SQL " .. act)
      or (act == "EXEC" and "EXEC SQL" or ("SQL " .. act))
  end
  return raw
end

function M.structures(bufnr)
  bufnr = bufnr or 0
  local root = M.parser(bufnr)
  if not root then return {} end
  local result, pending = {}, {}
  local function visit(node)
    local ntype = node:type()
    local spec = kinds[ntype]
    if spec then
      local sr, sc, er, ec = node:range()
      local item = {
        node = node,
        name = spec.name,
        ending = spec.ending,
        end_node_type = spec.end_node,
        label = format_structure_label(node, bufnr, spec.name),
        start_row = sr,
        start_col = sc,
        end_row = er,
        end_col = ec,
      }
      result[#result + 1] = item
      pending[#pending + 1] = item
    elseif ntype:match("^END_") then
      local item
      for i = #pending, 1, -1 do
        if pending[i].end_node_type == ntype then
          item = table.remove(pending, i)
          break
        end
      end
      if item then
        local sr, sc = node:start()
        local er, ec = node:end_()
        item.close_node = node
        item.close_row = sr
        item.close_col = sc
        item.end_row = er
        item.end_col = ec
        item.depth = #pending + 1
      end
    end
    for child in node:iter_children() do
      visit(child)
    end
  end
  visit(root)
  for _, item in ipairs(result) do
    if not item.depth then item.depth = 1 end
  end
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
    if after_open and before_close then
      active[#active + 1] = item
    end
  end
  table.sort(active, function(a, b) return a.depth > b.depth end)
  return active
end

function M.closure_stack(bufnr, row, col)
  local out = {}
  for _, item in ipairs(M.at_cursor(bufnr, row, col)) do
    out[#out + 1] = item.ending .. " (" .. item.label .. ")"
  end
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
  local active = M.at_cursor(bufnr, row, col)
  local item = active[1]
  if not item then
    -- Check if cursor is directly on a closing END_* statement
    for _, s in ipairs(M.structures(bufnr)) do
      if s.close_row and row == s.close_row and col >= s.close_col and col <= s.end_col then
        return { s.start_row, s.start_col }
      end
    end
    return nil
  end
  if row == item.start_row and col <= item.start_col + #item.name then
    return item.close_row and { item.close_row, item.close_col } or nil
  end
  if item.close_row and row == item.close_row then
    return { item.start_row, item.start_col }
  end
  return item.close_row and { item.close_row, item.close_col } or { item.start_row, item.start_col }
end

function M.aerial_items(bufnr)
  bufnr = bufnr or 0
  local items = {}
  -- 1. Paired structures (IF, EVALUATE, PERFORM, SEARCH, READ, WRITE, REWRITE, DELETE, START, etc.)
  for _, item in ipairs(M.structures(bufnr)) do
    items[#items + 1] = {
      name = item.label,
      kind = "Function",
      lnum = item.start_row + 1,
      col = item.start_col,
      end_lnum = (item.close_row or item.end_row) + 1,
      end_col = item.end_col,
      children = {},
    }
  end

  -- 2. WHEN clauses and CALL statements from AST root
  local root = M.parser(bufnr)
  local when_nodes = {}
  if root then
    local function walk(node)
      local ntype = node:type()
      if ntype == "when" then
        local sr, sc, er, ec = node:range()
        local label = format_structure_label(node, bufnr, "WHEN")
        local item = {
          name = label,
          kind = "Case",
          lnum = sr + 1,
          col = sc,
          end_lnum = er + 1,
          end_col = ec,
          children = {},
        }
        items[#items + 1] = item
        when_nodes[#when_nodes + 1] = item
      elseif ntype == "call_statement" then
        local sr, sc, er, ec = node:range()
        local label = format_structure_label(node, bufnr, "CALL")
        items[#items + 1] = {
          name = label,
          kind = "Method",
          lnum = sr + 1,
          col = sc,
          end_lnum = er + 1,
          end_col = ec,
          children = {},
        }
      end
      for child in node:iter_children() do
        walk(child)
      end
    end
    walk(root)
  end

  -- Extend WHEN node end_lnum to next WHEN or enclosing EVALUATE close_row
  for i, w in ipairs(when_nodes) do
    local next_w = when_nodes[i + 1]
    local limit = next_w and (next_w.lnum - 1) or nil
    if not limit then
      for _, s in ipairs(M.structures(bufnr)) do
        if s.name == "EVALUATE" and s.start_row + 1 <= w.lnum and (s.close_row or s.end_row) + 1 >= w.lnum then
          limit = (s.close_row or s.end_row)
          break
        end
      end
    end
    if limit and limit >= w.lnum then
      w.end_lnum = limit
    end
  end

  table.sort(items, function(a, b)
    if a.lnum == b.lnum then return (a.end_lnum - a.lnum) > (b.end_lnum - b.lnum) end
    return a.lnum < b.lnum
  end)
  return items
end

function M.setup_highlights()
  for i, color in ipairs(palette) do
    vim.api.nvim_set_hl(0, "CobolStructure" .. i, { fg = color, bold = true, default = true })
  end
  vim.api.nvim_set_hl(0, "CobolWaitingClosure", { fg = "#e5c07b", default = true })
end

function M.breadcrumb(bufnr, winid)
  bufnr = bufnr or 0
  winid = winid or vim.api.nvim_get_current_win()
  local state = M.update(bufnr, winid)
  return state and state.breadcrumb or ""
end

function M.statusline(bufnr)
  bufnr = bufnr or 0
  local crumb = vim.w.cobol_ast_breadcrumb or M.breadcrumb(bufnr)
  return crumb ~= "" and ("[ " .. crumb .. " ]") or ""
end

function M.show_breadcrumb_float(winid)
  winid = winid or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local crumb = M.breadcrumb(bufnr, winid)
  local lines = crumb ~= "" and vim.split(crumb, " > ", { plain = true }) or { "No COBOL AST breadcrumb" }
  local width = 40
  for _, l in ipairs(lines) do width = math.max(width, #l + 4) end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = " Breadcrumb ",
  })
  local close = function() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true })
  return win
end

function M.show_waiting_closures_float(winid)
  winid = winid or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local stack = M.closure_stack(bufnr, cursor[1] - 1, cursor[2])
  local lines = #stack > 0 and stack or { "No waiting closures" }
  local width = 40
  for _, l in ipairs(lines) do width = math.max(width, #l + 4) end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = " Waiting Closures ",
  })
  local close = function() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true })
  return win
end

function M.foldtext_for_line(bufnr, lnum)
  bufnr = bufnr or 0
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
  for _, item in ipairs(M.structures(bufnr)) do
    if item.start_row == lnum - 1 then
      return "+-- " .. item.label
    end
  end
  local clean = line:gsub("^%s%s%s%s%s%s%s?", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return "+-- " .. clean
end

function M.update(bufnr, winid)
  bufnr = bufnr or 0
  winid = winid or vim.api.nvim_get_current_win()
  if not M.parser(bufnr) then return nil end
  local ns = vim.api.nvim_create_namespace("cobol_ast_navigation")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local crow, ccol = cursor[1] - 1, cursor[2]
  local active = M.at_cursor(bufnr, crow, ccol)
  for _, item in ipairs(active) do
    local hl = "CobolStructure" .. ((item.depth - 1) % #palette + 1)
    vim.api.nvim_buf_set_extmark(bufnr, ns, item.start_row, item.start_col, {
      end_row = item.start_row,
      end_col = math.min(item.start_col + #item.name, item.end_col),
      hl_group = hl,
      priority = 140,
    })
    if item.close_row then
      vim.api.nvim_buf_set_extmark(bufnr, ns, item.close_row, item.close_col, {
        end_row = item.close_row,
        end_col = item.end_col,
        hl_group = hl,
        priority = 140,
      })
    end
  end
  local ancestors, node = {}, vim.treesitter.get_node({ bufnr = bufnr, pos = { crow, ccol } })
  local when_clause = nil
  while node do
    local kind = node:type()
    if kind == "procedure_division" or kind == "section_header" or kind == "paragraph_header" then
      table.insert(ancestors, 1, clean_label(node_text(node, bufnr)))
    elseif kind == "when" and not when_clause then
      when_clause = format_structure_label(node, bufnr, "WHEN")
    end
    node = node:parent()
  end
  for i = #active, 1, -1 do
    ancestors[#ancestors + 1] = active[i].label
  end
  if when_clause then
    ancestors[#ancestors + 1] = when_clause
  end
  local waiting = M.closure_stack(bufnr, crow, ccol)
  local breadcrumb = table.concat(ancestors, " > ")
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.w[winid].cobol_ast_breadcrumb = breadcrumb
    vim.w[winid].cobol_waiting_closures = waiting
  end
  return { breadcrumb = breadcrumb, waiting = waiting, active = active }
end

return M
