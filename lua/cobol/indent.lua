local M = {}

local close_kind = {
  ["END-IF"] = "IF",
  ["END-EVALUATE"] = "EVALUATE",
  ["END-PERFORM"] = "PERFORM",
  ["END-READ"] = "READ",
  ["END-SEARCH"] = "SEARCH",
  ["END-WRITE"] = "WRITE",
  ["END-REWRITE"] = "REWRITE",
  ["END-START"] = "START",
  ["END-EXEC"] = "EXEC",
}

local function source_text(line)
  if #line >= 7 then return line:sub(8) end
  return line
end

local function is_comment(line)
  return #line >= 7 and (line:sub(7, 7) == "*" or line:sub(7, 7) == "/")
end

local function block_kind(text)
  local upper = vim.trim(text):upper()
  if upper:match("^IF%f[%W]") and not upper:find("END%-IF", 1, false) then return "IF" end
  if upper:match("^EVALUATE%f[%W]") and not upper:find("END%-EVALUATE", 1, false) then return "EVALUATE" end
  if upper:match("^PERFORM%f[%W]") and (upper:find("UNTIL", 1, true) or upper:find("VARYING", 1, true) or upper:find(" TIMES", 1, true))
    and not upper:find("END%-PERFORM", 1, false) then return "PERFORM" end
  if upper:match("^READ%f[%W]") and not upper:find("END%-READ", 1, false) then return "READ" end
  for _, kind in ipairs({ "SEARCH", "WRITE", "REWRITE", "START", "EXEC" }) do
    if upper:match("^" .. kind .. "%f[%W]") and not upper:find("END%-" .. kind, 1, false) then return kind end
  end
end

local function branch_kind(text)
  local upper = vim.trim(text):upper()
  if upper:match("^ELSE%f[%W]") then return "IF" end
  if upper:match("^WHEN%f[%W]") then return "EVALUATE" end
  if upper:match("^(NOT%s+)?AT%s+END%f[%W]") or upper:match("^INVALID%s+KEY%f[%W]") then return "READ" end
end

local function nearest_block(stack, kind)
  for i = #stack, 1, -1 do
    if stack[i].kind == kind then return i, stack[i] end
  end
end

local function data_indent(level, stack)
  if level == 1 or level == 77 then
    stack = {}
    stack[#stack + 1] = { level = level, indent = 7, group = true }
    return 7, stack
  end
  if level == 88 then
    local parent = stack[#stack]
    local indent = parent and parent.indent + 4 or 11
    return indent, stack
  end
  while #stack > 0 and stack[#stack].level >= level do table.remove(stack) end
  local parent = stack[#stack]
  local indent = parent and parent.indent + 4 or 11
  local line_is_group = false
  return indent, stack, line_is_group
end

function M.compute(lines, target_lnum)
  target_lnum = math.max(1, target_lnum or (#lines + 1))
  local in_data, in_procedure = false, false
  local stack, data_stack = {}, {}
  local next_indent, last_data_group = 7, false

  for lnum = 1, math.min(target_lnum - 1, #lines) do
    local line = lines[lnum] or ""
    if not is_comment(line) and vim.trim(line) ~= "" then
      local text = source_text(line)
      local upper = vim.trim(text):upper()
      if upper:match("^[%w%-]+%s+DIVISION%s*%.") then
        in_data = upper:match("^DATA%s+DIVISION") ~= nil
        in_procedure = upper:match("^PROCEDURE%s+DIVISION") ~= nil
        stack, data_stack = {}, {}
        next_indent = 7
      elseif upper:match("^[%w%-]+%s+SECTION%s*%.") then
        stack = {}
        next_indent = 7
      elseif in_data then
        local level = tonumber(upper:match("^(%d%d)%s+"))
        if level then
          local indent
          indent, data_stack = data_indent(level, data_stack)
          last_data_group = not upper:match("%f[%a]PIC%f[%A]") and not upper:match("%f[%a]PICTURE%f[%A]")
          data_stack[#data_stack + 1] = { level = level, indent = indent, group = last_data_group }
          next_indent = last_data_group and indent + 4 or (data_stack[#data_stack - 1] and data_stack[#data_stack - 1].indent + 4 or indent)
          if level == 1 or level == 77 then next_indent = 11 end
        elseif upper:match("^FD%s+") or upper:match("^SD%s+") then
          data_stack, next_indent = {}, 7
        end
      elseif in_procedure then
        local body = vim.trim(text):upper()
        local end_kind
        for token, kind in pairs(close_kind) do
          if body:match("^" .. vim.pesc(token) .. "%f[%W]") then end_kind = kind; break end
        end
        if end_kind then
          local index, opener = nearest_block(stack, end_kind)
          next_indent = opener and opener.indent or 11
          if index then for i = #stack, index, -1 do table.remove(stack) end end
        else
          local branch = branch_kind(body)
          if branch then
            local _, opener = nearest_block(stack, branch)
            next_indent = opener and opener.indent + 4 or (11 + #stack * 4)
          else
            local first = body:match("^([%w%-]+)") or ""
            local structural = body:match("^[%w%-]+%s*%.$") and not ({
              GOBACK = true, EXIT = true, CONTINUE = true, DISPLAY = true, STOP = true,
              ACCEPT = true, CALL = true, MOVE = true, ADD = true, SUBTRACT = true,
              COMPUTE = true, PERFORM = true, GO = true, GOTO = true, IF = true,
            })[first]
            if structural then
              stack = {}
              next_indent = 7
            else
              local indent = 11 + #stack * 4
              next_indent = indent
              local kind = block_kind(body)
              if kind then
                stack[#stack + 1] = { kind = kind, indent = indent }
                next_indent = indent + 4
              end
              if body:find("END%-[A-Z]+", 1, false) and kind then
                local index = nearest_block(stack, kind)
                if index then table.remove(stack, index) end
              end
            end
          end
        end
        if body:match("%.$") then stack = {} end
      end
    end
  end

  local target = lines[target_lnum] or ""
  if target ~= "" and is_comment(target) then return -1 end
  local sequence = target:sub(1, 6)
  if sequence:match("%S") then return -1 end
  local indicator = target:sub(7, 7)
  if indicator ~= "" and indicator ~= " " and indicator ~= "\t" then return -1 end
  if #target > 72 and target:sub(73):match("%S") then return -1 end
  local body = vim.trim(source_text(target)):upper()
  if in_procedure then
    for token, kind in pairs(close_kind) do
      if body:match("^" .. vim.pesc(token) .. "%f[%W]") then
        local _, opener = nearest_block(stack, kind)
        if opener then return opener.indent end
      end
    end
    local branch = branch_kind(body)
    if branch then
      local _, opener = nearest_block(stack, branch)
      if opener then return opener.indent end
    end
    if body:match("^[%w%-]+%s*%.$") then
      local word = body:match("^([%w%-]+)")
      if word ~= "GOBACK" and word ~= "CONTINUE" and word ~= "EXIT" then return 7 end
    end
  elseif in_data then
    local level = tonumber(body:match("^(%d%d)%s+"))
    if level then return (data_indent(level, vim.deepcopy(data_stack))) end
  end
  return next_indent or 7
end

function M.get_indent(lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.max(vim.api.nvim_buf_line_count(bufnr), lnum), false)
  return M.compute(lines, lnum)
end

function M.setup(bufnr)
  vim.bo[bufnr].indentexpr = "v:lua.require'cobol.indent'.get_indent(v:lnum)"
  vim.bo[bufnr].indentkeys = "o,O,0=END-IF,0=END-EVALUATE,0=END-PERFORM,0=END-READ,0=END-SEARCH,0=END-WRITE,0=END-EXEC,0=ELSE,0=WHEN"
end

return M
