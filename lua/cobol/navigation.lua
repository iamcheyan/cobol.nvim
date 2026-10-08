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
  ".cbl",
  ".cob",
}

local function find_case_insensitive(directory, filename)
  if vim.fn.isdirectory(directory) ~= 1 then return nil end
  local wanted = filename:lower()
  for entry in vim.fs.dir(directory) do
    if entry:lower() == wanted then
      local candidate = directory .. "/" .. entry
      if vim.fn.filereadable(candidate) == 1 then return candidate end
    end
  end
end

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
function M.find_copybooks(name, current_file, search_paths)
  if not name or name == "" then
    return {}
  end
  current_file = current_file or vim.api.nvim_buf_get_name(0)
  local ok_cobol, cobol = pcall(require, "cobol")
  local ok_project, project = pcall(require, "cobol.project")
  local discovered_root = ok_project and project.find_root(current_file)
  local base_dir
  if discovered_root then
    base_dir = discovered_root
  elseif ok_cobol and cobol.get_project_root then
    base_dir = cobol.get_project_root(0, current_file)
  else
    base_dir = vim.fn.fnamemodify(current_file, ":p:h")
  end
  if not search_paths then
    if discovered_root then
      search_paths = project.settings(discovered_root, ok_cobol and cobol.config or {}).copybook_paths
    end
    search_paths = search_paths or (ok_cobol and cobol.get_copybook_paths and cobol.get_copybook_paths())
      or M.default_copybook_paths
  end

  local has_ext = name:match("%.[%w]+$") ~= nil

  local results, seen = {}, {}
  for _, rel_dir in ipairs(search_paths) do
    rel_dir = vim.fn.expand(rel_dir)
    local is_absolute = vim.startswith(rel_dir, "/") or rel_dir:match("^%a:[/\\]")
    local abs_dir = (rel_dir == "." and base_dir) or (is_absolute and rel_dir)
      or vim.fn.simplify(base_dir .. "/" .. rel_dir)
    if has_ext then
      local candidate = find_case_insensitive(abs_dir, name)
      if candidate then results[#results + 1] = candidate end
    else
      for _, ext in ipairs(M.default_extensions) do
        local candidate = find_case_insensitive(abs_dir, name .. ext)
        if candidate then results[#results + 1] = candidate end
      end
    end
  end
  local unique = {}
  for _, path in ipairs(results) do
    local normalized = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
    if not seen[normalized] then
      seen[normalized] = true
      unique[#unique + 1] = normalized
    end
  end
  return unique
end

function M.find_copybook(name, current_file, search_paths)
  return M.find_copybooks(name, current_file, search_paths)[1]
end

-- 在当前 buffer 中查找目标符号定义（Paragraph / Section / Data item）
function M.find_definition(target, bufnr)
  if not target or target == "" then
    return nil
  end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local upper_target = target:upper()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local line_order = {}
  for lnum = cursor_line, #lines do
    line_order[#line_order + 1] = lnum
  end
  for lnum = 1, cursor_line - 1 do
    line_order[#line_order + 1] = lnum
  end

  local escaped = vim.pesc(upper_target)
  local pattern_para = "^%s*" .. escaped .. "%s*[%s%.]"
  local pattern_sec = "^%s*" .. escaped .. "%s+SECTION%s*[%s%.]"

  -- 1. 优先在 PROCEDURE DIVISION 查找 Paragraph 或 Section
  for _, lnum in ipairs(line_order) do
    local raw_line = lines[lnum]
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

  for _, lnum in ipairs(line_order) do
    local raw_line = lines[lnum]
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

local symbol_cache = {}

local function buffer_for_path(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" and vim.fs.normalize(vim.fn.fnamemodify(name, ":p")) == path then
        return bufnr
      end
    end
  end
end

local function parse_file_index(lines, filename)
  local index = { symbols = {}, copybooks = {} }
  local in_data, in_procedure = false, false
  for lnum, raw in ipairs(lines) do
    local indicator = #raw >= 7 and raw:sub(7, 7) or ""
    if indicator ~= "*" and indicator ~= "/" and not raw:match("^%s*%*>") then
      local text = raw
      if #raw >= 7 then text = raw:sub(8) end
      if text:match("^%d%d%d%d%d%d[ %*]") then text = text:sub(8) end
      text = text:gsub("%*>.*$", "")
      local upper = vim.trim(text):upper()
      if upper:match("^DATA%s+DIVISION%f[%s%.]") then
        in_data, in_procedure = true, false
      elseif upper:match("^PROCEDURE%s+DIVISION%f[%s%.]") then
        in_data, in_procedure = false, true
      elseif upper:match("^[%w%-]+%s+DIVISION%f[%s%.]") then
        in_data, in_procedure = false, false
      end

      local copyname = M.get_copybook_name_on_line(raw)
      if copyname then index.copybooks[#index.copybooks + 1] = copyname end

      local name, kind
      if in_procedure then
        name = upper:match("^([%w%-]+)%s*%.$")
        if name then kind = "procedure" end
        if not name then
          name = upper:match("^([%w%-]+)%s+SECTION%s*%.")
          if name then kind = "procedure" end
        end
      elseif in_data or not in_procedure then
        name = upper:match("^%d%d%s+([%w%-]+)%f[%s%.]")
          or upper:match("^[Ff][Dd]%s+([%w%-]+)%f[%s%.]")
          or upper:match("^[Ss][Dd]%s+([%w%-]+)%f[%s%.]")
        if name then kind = "data" end
      end
      if name and kind then
        local list = index.symbols[name] or {}
        list[#list + 1] = {
          type = kind,
          name = name,
          lnum = lnum,
          col = (raw:upper():find(name, 1, true) or 1) - 1,
          line = raw,
          filename = filename,
        }
        index.symbols[name] = list
      end
    end
  end
  return index
end

local function cached_file_index(path, supplied_bufnr, supplied_lines)
  path = path ~= "" and vim.fs.normalize(vim.fn.fnamemodify(path, ":p")) or ""
  local bufnr = supplied_bufnr or (path ~= "" and buffer_for_path(path))
  local lines = supplied_lines
  local signature
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    lines = lines or vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    signature = "buffer:" .. vim.api.nvim_buf_get_changedtick(bufnr)
  else
    local stat = path ~= "" and vim.uv.fs_stat(path)
    if not lines and path ~= "" then
      local ok, read_lines = pcall(vim.fn.readfile, path)
      if not ok then return nil end
      lines = read_lines
    end
    lines = lines or {}
    signature = stat and string.format("disk:%d:%d:%d:%d", stat.size,
      stat.mtime.sec, stat.mtime.nsec or 0, stat.ctime.sec) or table.concat(lines, "\n")
  end
  local cached = symbol_cache[path]
  if cached and cached.signature == signature then return cached.index end
  local index = parse_file_index(lines, path)
  symbol_cache[path] = { signature = signature, index = index }
  return index
end

function M.invalidate_cache(path)
  if path then
    symbol_cache[vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))] = nil
  else
    symbol_cache = {}
  end
end

local cache_group = vim.api.nvim_create_augroup("CobolNavigationIndex", { clear = true })
vim.api.nvim_create_autocmd({ "BufWritePost", "BufDelete", "BufWipeout" }, {
  group = cache_group,
  pattern = "*",
  callback = function(event)
    local name = event.file
    if name and name ~= "" then M.invalidate_cache(name) end
  end,
})

-- Search current source and its complete reachable Copybook graph.
function M.find_definitions(target, bufnr)
  if not target or target == "" then return {} end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local pending = { { filename = filename, lines = lines, bufnr = bufnr } }
  local seen, results = {}, {}

  local ok_project, project = pcall(require, "cobol.project")
  local root = ok_project and project.find_root(filename) or nil
  local ok_cobol, cobol = pcall(require, "cobol")
  local paths = ok_project and root and project.settings(root, ok_cobol and cobol.config or {}).copybook_paths
    or (ok_cobol and cobol.get_copybook_paths and cobol.get_copybook_paths())
    or M.default_copybook_paths

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  while #pending > 0 do
    local file = table.remove(pending, 1)
    local file_path = file.filename
    local canonical = file_path ~= "" and vim.fs.normalize(vim.fn.fnamemodify(file_path, ":p")) or ""
    if canonical == "" or not seen[canonical] then
      if canonical ~= "" then seen[canonical] = true end
      local index = cached_file_index(file_path, file.bufnr, file.lines)
      if index then
        for _, definition in ipairs(index.symbols[target:upper()] or {}) do
          results[#results + 1] = vim.deepcopy(definition)
        end
        for _, copyname in ipairs(index.copybooks) do
          for _, copy_path in ipairs(M.find_copybooks(copyname, file_path, paths)) do
            if not seen[copy_path] then pending[#pending + 1] = { filename = copy_path } end
          end
        end
      end
    end
  end
  table.sort(results, function(a, b)
    if a.filename == filename and b.filename ~= filename then return true end
    if b.filename == filename and a.filename ~= filename then return false end
    if a.filename == b.filename then
      return math.abs(a.lnum - cursor_line) < math.abs(b.lnum - cursor_line)
    end
    return a.filename < b.filename
  end)
  return results
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
  local definitions = M.find_definitions(word, bufnr)
  if #definitions == 0 then
    vim.notify("COBOL: Definition not found for '" .. word .. "'", vim.log.levels.WARN)
    return
  end
  local function jump(def)
    local cur_win = vim.api.nvim_get_current_win()
    local from = { bufnr, vim.fn.line("."), vim.fn.col("."), 0 }
    local origin = vim.api.nvim_win_get_cursor(cur_win)
    pcall(vim.fn.settagstack, cur_win, { items = { { tagname = word, from = from } } }, "t")
    vim.cmd("normal! m'")
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count > 1 then
      vim.cmd(origin[1] < line_count and "normal! G" or "normal! gg")
      vim.api.nvim_win_set_cursor(cur_win, origin)
    end
    local source_name = vim.api.nvim_buf_get_name(bufnr)
    local same_buffer = def.filename == "" or (source_name ~= "" and
      vim.fs.normalize(vim.fn.fnamemodify(source_name, ":p")) == vim.fs.normalize(def.filename))
    if not same_buffer then
      local target_buf = buffer_for_path(def.filename)
      if target_buf then
        vim.api.nvim_win_set_buf(cur_win, target_buf)
      else
        vim.cmd("edit " .. vim.fn.fnameescape(def.filename))
      end
    end
    vim.api.nvim_win_set_cursor(cur_win, { def.lnum, def.col })
    vim.cmd("normal! zz")
    local kind = (def.type == "procedure") and "Paragraph" or "Data Field"
    vim.notify(string.format("COBOL: Jumped to %s '%s' (%s:%d)", kind, def.name,
      vim.fn.fnamemodify(def.filename, ":t"), def.lnum), vim.log.levels.INFO)
  end
  if #definitions == 1 then
    jump(definitions[1])
  else
    vim.ui.select(definitions, {
      prompt = "COBOL definitions for " .. word,
      format_item = function(def)
        return string.format("%s:%d  %s", vim.fn.fnamemodify(def.filename, ":~:."), def.lnum, def.line)
      end,
    }, function(choice) if choice then jump(choice) end end)
  end
end

-- 跳转到 Copybook 文件 (gf)
function M.goto_copybook()
  local line = vim.api.nvim_get_current_line()
  local name = M.get_copybook_name_on_line(line) or M.get_word_under_cursor()
  local paths = M.find_copybooks(name)
  if #paths == 0 then
    vim.notify("COBOL: Copybook not found: '" .. (name or "") .. "'", vim.log.levels.WARN)
    return
  end
  local function open(path)
    vim.cmd("normal! m'")
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  end
  if #paths == 1 then
    open(paths[1])
  else
    vim.ui.select(paths, {
      prompt = "Multiple Copybooks match " .. name,
      format_item = function(path) return vim.fn.fnamemodify(path, ":~:.") end,
    }, function(choice) if choice then open(choice) end end)
  end
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
  local definitions = M.find_definitions(word, bufnr)
  if #definitions == 0 then
    vim.notify("COBOL: No definition found for '" .. word .. "'", vim.log.levels.INFO)
    return
  end
  local function preview(def)
    local target_buf = def.filename == "" and bufnr or buffer_for_path(def.filename)
    local all_lines = target_buf and vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
      or (def.filename ~= "" and vim.fn.readfile(def.filename)) or {}
    local end_line = math.min(#all_lines, def.lnum + 18)
    local snippet_lines = vim.list_slice(all_lines, def.lnum, end_line)
    local type_str = (def.type == "procedure") and "Paragraph" or "Data Field"
    local source_label = def.filename ~= "" and vim.fn.fnamemodify(def.filename, ":t") or "[No Name]"
    local title = string.format(" 🔍 %s: %s (%s:%d) ", type_str, def.name, source_label, def.lnum)
    M.show_float_window(title, snippet_lines, "cobol")
  end
  if #definitions == 1 then
    preview(definitions[1])
  else
    vim.ui.select(definitions, {
      prompt = "COBOL definitions for " .. word,
      format_item = function(def)
        return string.format("%s:%d  %s", vim.fn.fnamemodify(def.filename, ":~:."), def.lnum, def.line)
      end,
    }, function(choice) if choice then preview(choice) end end)
  end
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
