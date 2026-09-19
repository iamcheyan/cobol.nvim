-- lua/cobol/navigation.lua
-- cobol.nvim: Code definition jumping (gd), Copybook navigation (gf), and hover preview (K)

local M = {}

-- 默认 Copybook 搜索相对路径
M.default_copybook_paths = {
  ".",
  "./cpy",
  "./copy",
  "./copybooks",
  "./include",
  "./cpylib",
  "../cpy",
  "../copy",
  "../copybooks",
  "../include",
}

-- 默认扩展名查找顺序
M.default_extensions = {
  "",
  ".cpy",
  ".CPY",
  ".cbl",
  ".CBL",
  ".cob",
  ".COB",
}

-- 提取光标所在 COBOL 标识符（连字符 - 为合法符号）
function M.get_word_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed
  local left = col
  while left > 1 and line:sub(left - 1, left - 1):match("[%w%-]") do
    left = left - 1
  end
  local right = col
  while right <= #line and line:sub(right, right):match("[%w%-]") do
    right = right + 1
  end
  if left < right then
    return line:sub(left, right - 1)
  end
  return vim.fn.expand("<cword>")
end

-- 提取当前行中的 COPY 目标文件名
function M.get_copybook_name_on_line(line)
  line = line or vim.api.nvim_get_current_line()
  -- 匹配 COPY "EMP-REC.CPY" 或 COPY 'EMP-REC.CPY' 或 COPY EMP-REC. 或 COPY EMP-REC
  local name = line:match("[Cc][Oo][Pp][Yy]%s+[\"']([^\"']+)[\"']")
  if not name then
    name = line:match("[Cc][Oo][Pp][Yy]%s+([A-Za-z0-9%-%._]+)")
  end
  if name then
    -- 去掉尾部可能附带的句号
    name = name:gsub("%.$", "")
  end
  return name
end

-- 查找 Copybook 绝对路径
function M.find_copybook(name, current_file, search_paths)
  if not name or name == "" then
    return nil
  end
  current_file = current_file or vim.api.nvim_buf_get_name(0)
  local base_dir = vim.fn.fnamemodify(current_file, ":p:h")
  search_paths = search_paths or M.default_copybook_paths

  local has_ext = name:match("%.[%w]+$") ~= nil

  for _, rel_dir in ipairs(search_paths) do
    local abs_dir = (rel_dir == ".") and base_dir or vim.fn.simplify(base_dir .. "/" .. rel_dir)
    if has_ext then
      local candidate = abs_dir .. "/" .. name
      if vim.fn.filereadable(candidate) == 1 then
        return candidate
      end
    else
      for _, ext in ipairs(M.default_extensions) do
        local candidate = abs_dir .. "/" .. name .. ext
        if vim.fn.filereadable(candidate) == 1 then
          return candidate
        end
      end
    end
  end

  return nil
end

-- 在当前 buffer 中查找目标符号定义（Paragraph / Section / Data item）
function M.find_definition(target, bufnr)
  if not target or target == "" then
    return nil
  end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local upper_target = target:upper()

  local escaped = vim.pesc(upper_target)
  local pattern_para = "^%s*" .. escaped .. "%s*[%s%.]"
  local pattern_sec = "^%s*" .. escaped .. "%s+SECTION%s*[%s%.]"

  -- 1. 优先在 PROCEDURE DIVISION 查找 Paragraph 或 Section
  for lnum, raw_line in ipairs(lines) do
    local is_comment = false
    if #raw_line >= 7 and (raw_line:sub(7, 7) == "*" or raw_line:sub(7, 7) == "/") then
      is_comment = true
    elseif raw_line:match("^%s*%*") then
      is_comment = true
    end

    if not is_comment then
      local line = raw_line:gsub("%*>.*$", "")
      if line:match("^%d%d%d%d%d%d[ %*]") then
        line = line:sub(8)
      end
      local upper = line:upper()

      if upper:match(pattern_para) or upper:match(pattern_sec) then
        local col = (raw_line:upper():find(upper_target, 1, true) or 1) - 1
        return {
          type = "procedure",
          name = target,
          lnum = lnum,
          col = col,
          line = raw_line,
        }
      end
    end
  end

  -- 2. 其次在 DATA DIVISION / ENVIRONMENT DIVISION 查找变量、字段、01/88 级、FD
  local pattern_data = "^%s*%d%d%s+" .. escaped .. "%f[%s%.]"
  local pattern_fd = "^%s*[FfSs][Dd]%s+" .. escaped .. "%f[%s%.]"

  for lnum, raw_line in ipairs(lines) do
    local is_comment = false
    if #raw_line >= 7 and (raw_line:sub(7, 7) == "*" or raw_line:sub(7, 7) == "/") then
      is_comment = true
    elseif raw_line:match("^%s*%*") then
      is_comment = true
    end

    if not is_comment then
      local line = raw_line:gsub("%*>.*$", "")
      if line:match("^%d%d%d%d%d%d[ %*]") then
        line = line:sub(8)
      end
      local upper = line:upper()

      if upper:match(pattern_data) or upper:match(pattern_fd) then
        local col = (raw_line:upper():find(upper_target, 1, true) or 1) - 1
        return {
          type = "data",
          name = target,
          lnum = lnum,
          col = col,
          line = raw_line,
        }
      end
    end
  end

  return nil
end

-- 浮动窗口展示预览内容
function M.show_float_window(title, lines, filetype)
  if not lines or #lines == 0 then
    return
  end

  local max_len = 0
  for _, l in ipairs(lines) do
    max_len = math.max(max_len, vim.fn.strdisplaywidth(l))
  end
  local width = math.min(math.max(max_len + 4, 40), 92)
  local height = math.min(#lines, 24)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })

  -- 按键监听：q 或 Esc 关闭浮窗
  local close_fn = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close_fn, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close_fn, { buffer = buf, nowait = true, silent = true })

  -- 离开窗口自动销毁
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buf,
    once = true,
    callback = close_fn,
  })
end

-- 跳转到定义 (gd)
function M.goto_definition()
  local word = M.get_word_under_cursor()
  if not word or word == "" then
    return
  end

  -- 如果当前行包含 COPY，且光标在 Copybook 名称处，触发文件跳转
  local copy_name = M.get_copybook_name_on_line()
  if copy_name and (word == copy_name or copy_name:find(word, 1, true)) then
    M.goto_copybook()
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local def = M.find_definition(word, bufnr)
  if not def then
    vim.notify("COBOL: Definition not found for '" .. word .. "'", vim.log.levels.WARN)
    return
  end

  -- 记录到 jumplist 和 tagstack，以便原生 <C-o> 或 <C-t> 准确回跳
  local cur_win = vim.api.nvim_get_current_win()
  local from = { bufnr, vim.fn.line("."), vim.fn.col("."), 0 }
  pcall(vim.fn.settagstack, cur_win, { items = { { tagname = word, from = from } } }, "t")
  vim.cmd("normal! m'")

  -- 执行跳转
  vim.api.nvim_win_set_cursor(cur_win, { def.lnum, def.col })
  vim.cmd("normal! zz")

  local type_label = (def.type == "procedure") and "Paragraph" or "Data Field"
  vim.notify(string.format("COBOL: Jumped to %s '%s' (line %d)", type_label, def.name, def.lnum), vim.log.levels.INFO)
end

-- 跳转到 Copybook 文件 (gf)
function M.goto_copybook()
  local line = vim.api.nvim_get_current_line()
  local name = M.get_copybook_name_on_line(line) or M.get_word_under_cursor()
  local path = M.find_copybook(name)
  if not path then
    vim.notify("COBOL: Copybook not found: '" .. (name or "") .. "'", vim.log.levels.WARN)
    return
  end
  vim.cmd("normal! m'")
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

-- 悬停预览 (K / Hover)
function M.hover_preview()
  local line = vim.api.nvim_get_current_line()
  local copy_name = M.get_copybook_name_on_line(line)

  -- 1. 如果光标在 COPY 语句上，预览 Copybook 文件内容
  if copy_name then
    local path = M.find_copybook(copy_name)
    if not path then
      vim.notify("COBOL: Copybook not found: '" .. copy_name .. "'", vim.log.levels.WARN)
      return
    end
    local file_lines = vim.fn.readfile(path, "", 35)
    local title = " 📖 Copybook: " .. vim.fn.fnamemodify(path, ":t") .. " "
    M.show_float_window(title, file_lines, "cobol")
    return
  end

  -- 2. 如果光标在某个段落/过程或变量名上，预览其定义处及后续代码片段
  local word = M.get_word_under_cursor()
  if not word or word == "" then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local def = M.find_definition(word, bufnr)
  if def then
    local total_lines = vim.api.nvim_buf_line_count(bufnr)
    local end_line = math.min(total_lines, def.lnum + 18)
    local snippet_lines = vim.api.nvim_buf_get_lines(bufnr, def.lnum - 1, end_line, false)
    local type_str = (def.type == "procedure") and "Paragraph" or "Data Field"
    local title = string.format(" 🔍 %s: %s (line %d) ", type_str, def.name, def.lnum)
    M.show_float_window(title, snippet_lines, "cobol")
    return
  end

  vim.notify("COBOL: No definition found for '" .. word .. "'", vim.log.levels.INFO)
end

-- 挂载按键映射到当前 buffer
function M.setup_keymaps(bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  map("n", "gd", function() M.goto_definition() end, "COBOL: Jump to Definition (Paragraph/Data)")
  map("n", "gf", function() M.goto_copybook() end, "COBOL: Open Copybook File")
  map("n", "K", function() M.hover_preview() end, "COBOL: Preview Definition / Copybook")
end

return M
