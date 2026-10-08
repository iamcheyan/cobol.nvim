-- lua/cobol/diagnostics.lua
-- cobol.nvim: Real-time GnuCOBOL (cobc) asynchronous syntax checking & Diagnostics engine

local M = {}

M.ns = vim.api.nvim_create_namespace("cobol_nvim_diagnostics")
M.running_jobs = {}
M.timers = {}
M.generations = {}
M.related_buffers = {}

local severity_map = {
  error = vim.diagnostic.severity.ERROR,
  fatal = vim.diagnostic.severity.ERROR,
  ["fatal error"] = vim.diagnostic.severity.ERROR,
  warning = vim.diagnostic.severity.WARN,
  note = vim.diagnostic.severity.INFO,
  info = vim.diagnostic.severity.INFO,
}

function M.is_enabled(bufnr)
  if not vim.diagnostic.is_enabled then
    return true
  end
  local ok, enabled = pcall(vim.diagnostic.is_enabled, {
    bufnr = bufnr,
    namespace = M.ns,
  })
  return not ok or enabled
end

local function absolute_path(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function candidate_paths(file, base_dir, search_dirs)
  if vim.startswith(file, "/") or file:match("^%a:[/\\]") then
    return { absolute_path(file) }
  end
  local candidates, seen = {}, {}
  local function add(path)
    path = absolute_path(path)
    if not seen[path] then
      seen[path] = true
      candidates[#candidates + 1] = path
    end
  end
  if base_dir then add(vim.fs.joinpath(base_dir, file)) end
  for _, directory in ipairs(search_dirs or {}) do
    add(vim.fs.joinpath(directory, file))
    local basename = vim.fs.basename(file)
    if vim.fn.isdirectory(directory) == 1 then
      for entry in vim.fs.dir(directory) do
        if entry:lower() == basename:lower() then add(vim.fs.joinpath(directory, entry)) end
      end
    end
  end
  return candidates
end

local function resolve_output_file(file, base_dir, search_dirs)
  local candidates = candidate_paths(file, base_dir, search_dirs)
  for _, candidate in ipairs(candidates) do
    if vim.fn.filereadable(candidate) == 1 then return candidate end
  end
  for _, candidate in ipairs(candidates) do
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) ~= ""
        and absolute_path(vim.api.nvim_buf_get_name(buf)) == candidate then
        return candidate
      end
    end
  end
  return candidates[1] or file
end

-- Match only the resolved path. Basename-only matching can send diagnostics
-- into an unrelated Copybook when projects contain duplicate file names.
local function find_buf_by_file(file, base_dir, search_dirs)
  local candidates = candidate_paths(file, base_dir, search_dirs)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        local norm_name = absolute_path(name)
        for _, candidate in ipairs(candidates) do
          if norm_name == candidate then return buf end
        end
      end
    end
  end
  return nil
end

-- 解析单行 cobc 诊断输出
function M.parse_line(line)
  -- 1. 上下文行: file: in paragraph/section '...'
  local f_ctx, ctx = line:match("^([^:]+):%s*in%s+([^:]+):%s*$")
  if f_ctx and ctx then
    return nil, { file = vim.trim(f_ctx), context = vim.trim(ctx) }
  end

  -- 2. file:line:col: severity: message
  local f1, l1, c1, sev1, msg1 = line:match("^(.*):(%d+):(%d+):%s*([%a ]+):%s*(.*)$")
  if f1 and l1 and c1 and sev1 and msg1 then
    return {
      file = vim.trim(f1),
      lnum = tonumber(l1),
      col = tonumber(c1),
      severity = vim.trim(sev1):lower(),
      message = vim.trim(msg1),
    }
  end

  -- 3. file:line: severity: message
  local f2, l2, sev2, msg2 = line:match("^(.*):(%d+):%s*([%a ]+):%s*(.*)$")
  if f2 and l2 and sev2 and msg2 then
    return {
      file = vim.trim(f2),
      lnum = tonumber(l2),
      col = nil,
      severity = vim.trim(sev2):lower(),
      message = vim.trim(msg2),
    }
  end

  -- 4. file: severity: message (无行号)
  local f3, sev3, msg3 = line:match("^(.*):%s*([%a ]+):%s*(.*)$")
  if f3 and sev3 and msg3 then
    local s = vim.trim(sev3):lower()
    if severity_map[s] then
      return {
        file = vim.trim(f3),
        lnum = 1,
        col = nil,
        severity = s,
        message = vim.trim(msg3),
      }
    end
  end

  return nil
end

-- 计算精准的代码高亮列区间
local function calculate_col_range(line_content, col, msg)
  local len = #line_content
  if len == 0 then
    return 0, 0
  end

  -- 如果 cobc 给出了列号
  if col and col > 0 then
    local start_c = math.max(0, math.min(col - 1, len - 1))
    -- 如果有带引号的具体标识符，尝试精确定位该标识符
    local token = msg:match("'([^']+)'")
    if token and #token > 0 then
      local s, e = line_content:find(token, start_c + 1, true)
      if s then
        return s - 1, e
      end
    end
    return start_c, math.max(start_c + 1, len)
  end

  -- 未给出列号时，优先在行内搜索消息中被引用的标识符 (如 'UNKNOWN-PARAGRAPH')
  local token = msg:match("'([^']+)'")
  if token and #token > 0 then
    local s, e = line_content:find(token, 1, true)
    if s then
      return s - 1, e
    end
  end

  -- 否则寻找第 7 列之后的第一个非空字符（跳过序号与指示列）
  local first_non_blank = line_content:find("%S", 7) or line_content:find("%S") or 1
  return first_non_blank - 1, len
end

-- 在主缓冲区中查找 COPY 语句所在的行号
local function find_copy_line(lines, copybook_file, source_file, search_paths)
  local target = absolute_path(copybook_file)
  local nav_ok, navigation = pcall(require, "cobol.navigation")
  for idx, line in ipairs(lines) do
    local copy_name = nav_ok and navigation.get_copybook_name_on_line(line)
    if copy_name then
      local candidates = navigation.find_copybooks(copy_name, source_file, search_paths)
      for _, candidate in ipairs(candidates) do
        if absolute_path(candidate) == target then return idx end
      end
    end
  end
  return nil
end

-- 解析并分发诊断信息到对应缓冲区
function M.process_output(bufnr, res, lines, base_dir, opts)
  opts = opts or {}
  if opts.generation and opts.current_generation and opts.current_generation() ~= opts.generation then
    return
  end
  local diags_by_buf = { [bufnr] = {} }
  for related in pairs(M.related_buffers[bufnr] or {}) do
    if related ~= bufnr and vim.api.nvim_buf_is_valid(related) then
      diags_by_buf[related] = {}
    end
  end
  local total_errors = 0
  local total_warnings = 0
  local ok_cobol, cobol = pcall(require, "cobol")
  local project = require("cobol.project")
  local settings = project.settings(base_dir, ok_cobol and cobol.config or {})
  local search_dirs = settings.copybook_dirs or { base_dir }
  local source_file = vim.api.nvim_buf_get_name(bufnr)

  if res.stderr and #res.stderr > 0 then
    local raw_lines = vim.split(res.stderr, "\n", { trimempty = true })
    for _, raw in ipairs(raw_lines) do
      local item = M.parse_line(raw)
      if item then
        local sev = severity_map[item.severity] or vim.diagnostic.severity.ERROR
        if sev == vim.diagnostic.severity.ERROR then
          total_errors = total_errors + 1
        elseif sev == vim.diagnostic.severity.WARN then
          total_warnings = total_warnings + 1
        end

        if item.file == "-" then
          -- 主缓冲区诊断
          local lnum = math.max(0, math.min(item.lnum - 1, #lines - 1))
          local line_str = lines[lnum + 1] or ""
          local start_col, end_col = calculate_col_range(line_str, item.col, item.message)

          table.insert(diags_by_buf[bufnr], {
            bufnr = bufnr,
            lnum = lnum,
            col = start_col,
            end_col = end_col,
            severity = sev,
            message = item.message,
            source = "cobc",
          })
        else
          -- 来自外部 Copybook 文件
          local resolved_file = resolve_output_file(item.file, base_dir, search_dirs)
          local cpy_buf = find_buf_by_file(resolved_file, base_dir, search_dirs)
          if cpy_buf then
            if not diags_by_buf[cpy_buf] then
              diags_by_buf[cpy_buf] = {}
            end
            local cpy_lines = vim.api.nvim_buf_get_lines(cpy_buf, 0, -1, false)
            local cpy_lnum = math.max(0, math.min(item.lnum - 1, #cpy_lines - 1))
            local cpy_str = cpy_lines[cpy_lnum + 1] or ""
            local start_col, end_col = calculate_col_range(cpy_str, item.col, item.message)

            table.insert(diags_by_buf[cpy_buf], {
              bufnr = cpy_buf,
              lnum = cpy_lnum,
              col = start_col,
              end_col = end_col,
              severity = sev,
              message = item.message,
              source = "cobc",
            })
          end

          -- 同时在主程序引用该 Copybook 的行上标注诊断
          local copy_line = find_copy_line(lines, resolved_file, source_file, settings.copybook_dirs)
          if copy_line then
            local copy_lnum = copy_line - 1
            local copy_str = lines[copy_line] or ""
            local start_col, end_col = calculate_col_range(copy_str, nil, "")
            table.insert(diags_by_buf[bufnr], {
              bufnr = bufnr,
              lnum = copy_lnum,
              col = start_col,
              end_col = end_col,
              severity = sev,
              message = string.format("[In %s:%d] %s", vim.fs.basename(resolved_file), item.lnum, item.message),
              source = "cobc",
            })
          end
        end
      end
    end
  end

  -- 应用诊断结果
  M.related_buffers[bufnr] = {}
  for related in pairs(diags_by_buf) do
    if related ~= bufnr then M.related_buffers[bufnr][related] = true end
  end
  for b, diags in pairs(diags_by_buf) do
    if vim.api.nvim_buf_is_valid(b) then
      if not M.is_enabled(b) then
        vim.notify_once(
          "COBOL: Neovim diagnostics are disabled for this buffer; compiler results are not visible.",
          vim.log.levels.WARN
        )
      end
      vim.diagnostic.set(M.ns, b, diags, {})
    end
  end

  -- 交互式命令通知
  if opts.interactive then
    if total_errors == 0 and total_warnings == 0 then
      vim.notify("COBOL: ✓ No syntax errors or warnings found by cobc.", vim.log.levels.INFO)
    else
      vim.notify(
        string.format("COBOL: %d error(s), %d warning(s) detected.", total_errors, total_warnings),
        total_errors > 0 and vim.log.levels.ERROR or vim.log.levels.WARN
      )
    end
  end
end

-- 立即执行语法飞检
function M.lint(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false, "invalid_buffer"
  end

  opts = opts or {}

  M.generations[bufnr] = (M.generations[bufnr] or 0) + 1
  local generation = M.generations[bufnr]

  local ok_c, cobol = pcall(require, "cobol")
  local plugin_cfg = (ok_c and cobol.config) or {}
  local project = require("cobol.project")
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local base_dir = project.find_root(bufname)
    or (ok_c and cobol.get_project_root and cobol.get_project_root(bufnr, bufname))
  if type(base_dir) ~= "string" or vim.fn.isdirectory(base_dir) ~= 1 then
    base_dir = vim.fn.getcwd()
  end
  local settings, profile_error = project.settings(base_dir, plugin_cfg)
  if profile_error then vim.notify_once("COBOL: " .. profile_error, vim.log.levels.WARN) end
  local diag_cfg = plugin_cfg.diagnostics or {}
  local compiler = settings.compiler

  -- 检查 GnuCOBOL 编译器是否存在
  if vim.fn.executable(compiler) ~= 1 then
    if opts.interactive then
      vim.notify("COBOL: '" .. compiler .. "' (GnuCOBOL) compiler not found in PATH.", vim.log.levels.WARN)
    end
    return false, "compiler_not_found"
  end

  -- 取消当前缓冲区的延迟定时器
  if M.timers[bufnr] then
    M.timers[bufnr]:stop()
    M.timers[bufnr]:close()
    M.timers[bufnr] = nil
  end

  -- 中止尚未执行完的旧作业
  if M.running_jobs[bufnr] then
    pcall(function()
      M.running_jobs[bufnr]:kill(9)
    end)
    M.running_jobs[bufnr] = nil
  end

  -- 获取配置
  if diag_cfg.enable == false and not opts.interactive then
    return false, "disabled"
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 then
    vim.diagnostic.set(M.ns, bufnr, {}, {})
    return true
  end

  local text = table.concat(lines, "\n") .. "\n"
  if settings.source_format == "auto" then
    settings.source_format = ok_c and cobol.detect_format and cobol.detect_format(bufnr) or "fixed"
  end
  if not base_dir then
    if opts.interactive then
      vim.notify("COBOL: no existing working directory is available for syntax checking.", vim.log.levels.ERROR)
    end
    return false, "invalid_working_directory"
  end

  -- 通过 STDIN 传递当前未保存的缓冲区内容
  local args = project.compiler_args(settings, base_dir, "check", "-")

  -- 异步调用 GnuCOBOL。目录可能在检查后被删除，防止同步 spawn 异常逃逸到定时回调。
  local command = vim.list_extend({ compiler }, args)
  local spawn_ok, job = pcall(vim.system, command, {
    stdin = text,
    cwd = base_dir,
    text = true,
  }, function(res)
    if M.generations[bufnr] ~= generation then
      return
    end
    M.running_jobs[bufnr] = nil
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) or M.generations[bufnr] ~= generation then
        return
      end
      local process_opts = vim.tbl_extend("force", opts, {
        generation = generation,
        current_generation = function()
          return M.generations[bufnr]
        end,
      })
      M.process_output(bufnr, res, lines, base_dir, process_opts)
    end)
  end)
  if not spawn_ok then
    M.running_jobs[bufnr] = nil
    if opts.interactive then
      vim.notify("COBOL: failed to start the syntax checker.", vim.log.levels.ERROR)
    end
    return false, "spawn_failed"
  end
  M.running_jobs[bufnr] = job
  return true
end

-- 带防抖的延迟飞检 (供 TextChanged / TextChangedI 使用)
function M.lint_debounced(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local ok_c, cobol = pcall(require, "cobol")
  local diag_cfg = (ok_c and cobol.config and cobol.config.diagnostics) or {}
  if diag_cfg.enable == false then
    return
  end

  local debounce = diag_cfg.debounce_ms or 600

  if M.timers[bufnr] then
    M.timers[bufnr]:stop()
  else
    M.timers[bufnr] = vim.uv.new_timer()
  end

  M.timers[bufnr]:start(debounce, 0, function()
    vim.schedule(function()
      if M.timers[bufnr] then
        M.timers[bufnr]:stop()
        M.timers[bufnr]:close()
        M.timers[bufnr] = nil
      end
      if vim.api.nvim_buf_is_valid(bufnr) then
        M.lint(bufnr)
      end
    end)
  end)
end

-- 清除缓冲区的诊断与后台任务
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if M.timers[bufnr] then
    M.timers[bufnr]:stop()
    M.timers[bufnr]:close()
    M.timers[bufnr] = nil
  end
  if M.running_jobs[bufnr] then
    pcall(function()
      M.running_jobs[bufnr]:kill(9)
    end)
    M.running_jobs[bufnr] = nil
  end
  M.generations[bufnr] = (M.generations[bufnr] or 0) + 1
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.diagnostic.reset(M.ns, bufnr)
  end
  for related in pairs(M.related_buffers[bufnr] or {}) do
    if vim.api.nvim_buf_is_valid(related) then vim.diagnostic.reset(M.ns, related) end
  end
  M.related_buffers[bufnr] = nil
end

-- 打开 Quickfix 列表展示所有 COBOL 语法诊断
function M.open_quickfix()
  vim.diagnostic.setqflist({ namespace = M.ns, open = true })
end

-- 快捷键配置
function M.setup_keymaps(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  -- <leader>cl: COBOL 手动语法飞检 (Cobol Lint)
  map("<leader>cl", function()
    M.lint(bufnr, { interactive = true })
  end, "COBOL: Run compiler syntax check (cobc)")

  -- <leader>cq: 打开诊断 Quickfix 列表 (Cobol Quickfix)
  map("<leader>cq", function()
    M.open_quickfix()
  end, "COBOL: Open diagnostics Quickfix list")
end

return M
