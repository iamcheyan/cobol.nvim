local M = {}
local function winbar_text(text)
  return (text:gsub("%%", "%%%%"))
end

local function clip_parts(parts, budget)
  local full = table.concat(parts, "  ")
  if vim.api.nvim_strwidth(full) <= budget then
    return full
  end
  budget = budget - 4 -- room for the leading "…  "
  local kept = {}
  local width = 0
  for i = #parts, 1, -1 do
    local part = parts[i]
    local cost = vim.api.nvim_strwidth(part) + (#kept > 0 and 3 or 0)
    if width + cost > budget and #kept > 0 then
      break
    end
    table.insert(kept, 1, part)
    width = width + cost
  end
  return "…  " .. table.concat(kept, "  ")
end

local function breadcrumb_highlight(parts)
  if not parts[1] then
    return "CobolBreadcrumbProc"
  end
  local division = parts[1]
  if division:find("DATA", 1, true) then
    return "CobolBreadcrumbData"
  elseif division:find("ENVIRONMENT", 1, true) then
    return "CobolBreadcrumbEnv"
  elseif division:find("IDENTIFICATION", 1, true) then
    return "CobolBreadcrumbId"
  end
  return "CobolBreadcrumbProc"
end

-- Waiting closures for the winbar's right edge, innermost first.
local function waiting_closure_parts(win_id, bufnr, budget)
  if not require("cobol").config.show_waiting_closures then
    return {}
  end
  local pos = vim.api.nvim_win_get_cursor(win_id)
  local stack = require("cobol.ast").closure_stack(bufnr, pos[1] - 1, pos[2])
  local kept = {}
  local width = 0
  for _, entry in ipairs(stack) do
    local cost = vim.api.nvim_strwidth(entry) + (#kept > 0 and 3 or 0)
    if width + cost > budget and #kept > 0 then
      break
    end
    kept[#kept + 1] = entry
    width = width + cost
  end
  if #kept < #stack then
    kept[#kept + 1] = "…"
  end
  return kept
end

function M.render(bufnr, win_id)
  local cobol = require("cobol")
  if not cobol.state.enabled then return "" end
  local width = vim.api.nvim_win_get_width(win_id)
  local avail = math.max(20, width - 2)

  local crumb_parts = {}
  local hl_group = "CobolBreadcrumbProc"
  if require("cobol").config.show_breadcrumbs then
    local pos = vim.api.nvim_win_get_cursor(win_id)
    local ok_chain, parts = pcall(require("cobol.ast").chain, bufnr, pos[1] - 1, pos[2])
    if ok_chain and parts and #parts > 0 then
      crumb_parts = parts
      hl_group = breadcrumb_highlight(parts)
    end
  end

  if not cobol.config.show_breadcrumbs then return "" end
  if #crumb_parts == 0 then crumb_parts = { "(root)" } end
  for index, part in ipairs(crumb_parts) do
    local icon = index == 1 and "󰌗" or index == 2 and "󰏗" or "󰊕"
    if part:match("^IF ") or part:match("^EVALUATE ") or part:match("^PERFORM ") then icon = "󰅩" end
    crumb_parts[index] = icon .. " " .. part
  end

  -- The breadcrumb is the primary signal: give it the space it needs and keep
  -- waiting closures only in what is left over, dropping them when there is no
  -- room instead of squeezing the chain down to its last part.
  local crumb_need = vim.api.nvim_strwidth(table.concat(crumb_parts, "  ")) + 4
  local waiting_budget = avail - crumb_need - 6
  local waiting_text = ""
  if waiting_budget >= 10 then
    local waiting = waiting_closure_parts(win_id, bufnr, waiting_budget)
    local candidate = waiting[1] and table.concat(waiting, "  ") or ""
    if vim.api.nvim_strwidth(candidate) + 4 > waiting_budget then
      -- Avoid repeating the active condition when the compact END-* names fit.
      candidate = candidate:gsub("%s+%b()", "")
    end
    if candidate ~= "" and vim.api.nvim_strwidth(candidate) + 4 <= waiting_budget then
      waiting_text = candidate
    end
  end
  local crumb_budget = avail
    - (waiting_text ~= "" and (vim.api.nvim_strwidth(waiting_text) + 4) or 0)
    - 4

  local winbar = "%#"
    .. hl_group
    .. "#[ "
    .. winbar_text(clip_parts(crumb_parts, math.max(12, crumb_budget)))
    .. " ]%*"
  if waiting_text ~= "" then
    winbar = winbar .. "%=" .. "%#CobolWaitingClosure#⌫ " .. winbar_text(waiting_text) .. " "
  end
  return winbar
end


-- Outline ranges come from the grammar and paired AST structures. Header
-- bodies end at the next header of the same or higher level in the flat grammar.
local function outline(buf)
  local ast = require('cobol.ast')
  local root = ast.parser(buf)
  if not root then return {} end
  local headers = {}
  local function walk(node)
    local kind = node:type()
    local level = kind:match('_division$') and 1
      or kind == 'section_header' and 2 or kind == 'paragraph_header' and 3
      or kind == 'data_description' and 4
    if level then
      local sr, sc, er, ec = node:range()
      local line = vim.api.nvim_buf_get_lines(buf, sr, sr+1, false)[1] or ''
      local label = line:sub(sc+1):match('^%s*(.-)%s*%.?%s*$') or kind
      headers[#headers+1] = {name=label, level=level, sr=sr, sc=sc, er=er, ec=ec}
    end
    for child in node:iter_children() do walk(child) end
  end
  walk(root)
  table.sort(headers, function(a,b) return a.sr < b.sr end)
  local last = vim.api.nvim_buf_line_count(buf)-1
  for i, item in ipairs(headers) do
    if item.level == 2 or item.level == 3 then
      item.er, item.ec = last, 1000000
      for j=i+1,#headers do
        if headers[j].level <= item.level then
          item.er, item.ec = headers[j].sr, headers[j].sc
          break
        end
      end
    end
  end
  local items = headers
  for _, item in ipairs(ast.aerial_items(buf)) do
    items[#items+1] = {name=item.name, sr=item.lnum-1, sc=item.col,
      er=item.end_lnum-1, ec=item.end_col, level=4}
  end
  table.sort(items, function(a,b)
    if a.sr ~= b.sr then return a.sr < b.sr end
    if a.sc ~= b.sc then return a.sc < b.sc end
    return a.er > b.er
  end)
  local roots, stack = {}, {}
  for _, item in ipairs(items) do
    item.range = {start={line=item.sr, character=item.sc}, ['end']={line=item.er, character=item.ec}}
    item.children = {}
    while #stack > 0 do
      local p = stack[#stack]
      if (p.er > item.er or (p.er == item.er and p.ec >= item.ec)) and p.level <= item.level then break end
      table.remove(stack)
    end
    local siblings = #stack > 0 and stack[#stack].children or roots
    siblings[#siblings+1] = item
    stack[#stack+1] = item
  end
  return roots
end

local function symbols(items, buf, win)
  local result = {}
  for index, item in ipairs(items) do
    result[#result+1] = require('dropbar.bar').dropbar_symbol_t:new(setmetatable({
      name=item.name, icon=(item.level == 1 and '󰌗 ' or item.level == 2 and '󰏗 ' or '󰊕 '), buf=buf, win=win, range=item.range,
    }, {__index=function(_, key)
      if key == 'children' then return symbols(item.children, buf, win) end
      if key == 'siblings' then return symbols(items, buf, win) end
      if key == 'sibling_idx' then return index end
    end}))
  end
  return result
end

function M.get_symbols(buf, win, _)
  local layout = M.render(buf, win)
  if layout == '' then return {} end
  local symbol = require('dropbar.bar').dropbar_symbol_t:new(setmetatable({
    name='', icon='', buf=buf, win=win,
  }, {__index=function(_, key)
    if key == 'siblings' then return symbols(outline(buf), buf, win) end
  end}))
  -- Override this symbol's public formatter, leaving dropbar's bar lifecycle,
  -- callback registry, native menu and all other symbol types unchanged.
  symbol.cat = function(self, plain)
    if plain then
      return vim.api.nvim_eval_statusline(layout, {winid=win, use_winbar=true}).str
    end
    if not self.bar then return layout end
    return require('dropbar.utils.bar').make_clickable(layout,
      string.format('v:lua.dropbar.callbacks.buf%s.win%s.fn%s', buf, win, self.callback_idx))
  end
  return {symbol}
end

return M
