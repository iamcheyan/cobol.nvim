-- lua/cobol/init.lua
-- cobol.nvim: Modern COBOL development & visual enhancement toolkit for Neovim

local M = {}

local default_config = {
  enabled = true,
  columns = { 7, 8, 12, 73 },  -- 标尺列：7 (Ind), 8 (Area A), 12 (Area B), 73 (Past Area B)
  show_lines = true,           -- 使用纯字符细线标尺 (│)，零背景色
  char = "│",                  -- 细线字符 (U+2502)
  show_winbar = true,          -- 顶部打孔卡刻度
  show_breadcrumbs = true,     -- 顶部 Winbar 实时显示 Division > Section > Paragraph 面包屑
  show_hierarchy_hint = true,  -- DATA DIVISION 行尾显示父级结构回溯 (← 05 PARENT)
  show_pic_size = true,        -- DATA DIVISION 实时显示字段字节数与 01 Record 内存总计
  highlight_levels = true,     -- 突出高亮 88 级条件名与 01 级记录
  show_colorcolumn = false,    -- 禁用粗背景色块
  highlight_overflow = true,   -- 72 列越界代码告警
  overflow_col = 72,
  disable_indent_guide = true, -- 自动禁用当前 COBOL buffer 的通用缩进线（如 ibl）
  smart_tab = true,            -- 智能对齐 Tab
  smart_comments = true,       -- 第 7 列智能注释切换
  keymaps = true,              -- 默认快捷键
  project_root = nil,          -- 项目根目录；未设置时使用当前文件目录
  source_format = "auto",     -- auto、fixed 或 free
  copybook_paths = { ".", "./cpy", "./copy", "./copybooks", "./include", "../copybooks", "../include" },
  cobc_command = "cobc",      -- GnuCOBOL 编译器命令
  cobc_extra_args = {},        -- 传给 cobc 的额外参数
  folding = {
    enable = true,              -- 使用 COBOL Division/Section/Paragraph 结构折叠
  },
  diagnostics = {
    enable = true,              -- 启用 GnuCOBOL 异步语法飞检与诊断
    on_save = true,             -- 保存时立即飞检 (BufWritePost)
    on_change = true,           -- 内容变更时防抖飞检 (TextChanged)
    debounce_ms = 600,          -- 防抖延时毫秒
    warnings = { "all", "no-obsolete" }, -- 编译器警告控制
    dialect = nil,              -- COBOL 方言 (默认 nil 使用 GnuCOBOL 原生)
    copybook_paths = nil,      -- 兼容旧配置；默认继承顶层 copybook_paths
  },
  completion = {
    enable = true,              -- 如果安装 blink.cmp，自动注册 COBOL source
  },
}

M.config = vim.deepcopy(default_config)
M.state = {
  enabled = true,
}

M.ns_ruler = vim.api.nvim_create_namespace("cobol_nvim_ruler")
M.ns_hint = vim.api.nvim_create_namespace("cobol_nvim_hint")

function M.register_completion()
  if not M.config.completion or not M.config.completion.enable then return false end

  local ok, blink = pcall(require, "blink.cmp")
  if not ok or type(blink.add_source_provider) ~= "function" then return false end

  pcall(blink.add_source_provider, "cobol", {
    name = "COBOL",
    module = "cobol.completion.blink",
    score_offset = 10,
  })

  if type(blink.add_filetype_source) == "function" then
    for _, filetype in ipairs({ "cobol", "cbl", "cob" }) do
      pcall(blink.add_filetype_source, filetype, "cobol")
    end
  end
  return true
end

function M.get_project_root(bufnr, current_file)
  local configured = M.config.project_root
  if type(configured) == "function" then
    configured = configured(bufnr or vim.api.nvim_get_current_buf())
  end
  if type(configured) == "string" and configured ~= "" then
    configured = vim.fn.expand(configured)
    if not vim.startswith(configured, "/") then
      configured = vim.fn.getcwd() .. "/" .. configured
    end
    return vim.fs.normalize(configured)
  end

  current_file = current_file or vim.api.nvim_buf_get_name(bufnr or vim.api.nvim_get_current_buf())
  if current_file and current_file ~= "" then
    return vim.fs.dirname(vim.fs.normalize(current_file))
  end
  return vim.fn.getcwd()
end

function M.get_copybook_paths()
  local paths = M.config.copybook_paths
  if M.config.diagnostics and M.config.diagnostics.copybook_paths then
    paths = M.config.diagnostics.copybook_paths
  end
  return paths or { "." }
end

function M.detect_format(bufnr)
  local configured = M.config.source_format
  if configured == "fixed" or configured == "free" then
    return configured
  end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(80, vim.api.nvim_buf_line_count(bufnr)), false)
  for _, line in ipairs(lines) do
    if line:match("^%d%d%d%d%d%d[%s*/]") or (#line >= 7 and (line:sub(7, 7) == "*" or line:sub(7, 7) == "/")) then
      return "fixed"
    end
    if line:match("^%s*[%w%-]+%s+DIVISION%s*%.") and not line:match("^%s%s%s%s%s%s%s") then
      return "free"
    end
  end
  return "fixed"
end

-- 初始化高亮组（融入 Fresh / Catppuccin / High Contrast 配色）
function M.setup_highlights()
  local set = function(group, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- 纯细线标尺配色：无背景色，使用清爽淡钢蓝，与缩进线风格融合
  set("CobolRulerLine", { fg = "#3b638c", bg = "NONE" })
  set("CobolRulerLineInd", { fg = "#4c78a8", bg = "NONE" })

  -- Winbar 标尺各区域配色
  set("CobolRulerBase", { fg = "#5c6370", bg = "#181c24" })
  set("CobolRulerSeq", { fg = "#6b7280", bg = "#181c24" })
  set("CobolRulerInd", { fg = "#e5c07b", bg = "#222730", bold = true })
  set("CobolRulerAreaA", { fg = "#61afef", bg = "#1f2735", bold = true })
  set("CobolRulerAreaB", { fg = "#98c379", bg = "#181c24" })
  set("CobolRulerIdent", { fg = "#e06c75", bg = "#251d22" })

  -- Winbar 动态面包屑配色
  set("CobolBreadcrumbProc", { fg = "#61afef", bg = "#1c212a", bold = true })
  set("CobolBreadcrumbData", { fg = "#98c379", bg = "#1c212a", bold = true })
  set("CobolBreadcrumbEnv", { fg = "#e5c07b", bg = "#1c212a", bold = true })
  set("CobolBreadcrumbId", { fg = "#c678dd", bg = "#1c212a", bold = true })

  -- Statusline context components, using the same semantic colors as the
  -- ruler, breadcrumbs, and data-layout virtual text above.
  set("CobolStatusFormat", { fg = "#61afef", bold = true })
  set("CobolStatusArea", { fg = "#98c379", bold = true })
  set("CobolStatusField", { fg = "#e5c07b", bold = true })
  set("CobolStatusPic", { fg = "#c678dd" })
  set("CobolStatusSize", { fg = "#56b6c2", bold = true })
  set("CobolStatusRecord", { fg = "#98c379", bold = true })

  -- DATA DIVISION 层级与 88 级高亮
  set("CobolLevel88", { fg = "#c678dd", bold = true })        -- 88 标志号（鲜明紫）
  set("CobolConditionName", { fg = "#e5c07b", bold = true })  -- 88 条件名（暖金黄）
  set("CobolLevel01", { fg = "#61afef", bold = true })        -- 01 顶级记录号（亮蓝）
  set("CobolHierarchyHint", { fg = "#5c6370", italic = true })-- 行尾宿主回溯虚词
  set("CobolSizeHint", { fg = "#7f848e", italic = true })      -- 字段字节数提示
  set("CobolRecordSizeHint", { fg = "#98c379", bold = true })  -- 01 Record 内存总计提示

  -- 72 列越界代码高亮（醒目告警）
  set("CobolColumnOverflow", {
    fg = "#ff7b72",
    bg = "#382024",
    undercurl = true,
    sp = "#ff7b72",
    bold = true,
  })

  -- 备用兼容 ColorColumn
  set("CobolRulerCol", {
    bg = "#232832",
  })
end

local function setup_folding(bufnr)
  if not M.config.folding or not M.config.folding.enable then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= bufnr then
    return
  end
  vim.wo[win].foldmethod = "expr"
  vim.wo[win].foldexpr = "v:lua.require('cobol.folding').foldexpr(v:lnum)"
  vim.wo[win].foldenable = true
end

-- 解析当前行在 COBOL 架构中的面包屑路径
function M.get_breadcrumb(bufnr, cursor_row)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  cursor_row = cursor_row or vim.api.nvim_win_get_cursor(0)[1]

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor_row, false)
  if not lines or #lines == 0 then
    return nil, "CobolBreadcrumbProc"
  end

  local div, sec, para
  local current_line = lines[cursor_row] or ""

  -- 向上扫描定位当前所属的 Division, Section 和 Paragraph
  for i = #lines, 1, -1 do
    local line = lines[i]
    -- 跳过固定格式注释行（第 7 列为 * 或 /）
    if not (line:len() >= 7 and (line:sub(7, 7) == "*" or line:sub(7, 7) == "/")) then
      local trimmed = vim.trim(line)

      if not div then
        local d = trimmed:match("^([%w%-]+)%s+DIVISION%s*%.")
        if d then
          div = d
        end
      end

      if not sec then
        local s = trimmed:match("^([%w%-]+)%s+SECTION%s*%.")
        if s then
          sec = s
        end
      end

      if not para and (not div or div == "PROCEDURE") then
        -- COBOL 段落名必须顶格写在 Area A（前导 7 个空格）并以 '.' 结尾
        local p = line:match("^%s%s%s%s%s%s%s([%w%-]+)%.%s*$")
        if not p then
          p = trimmed:match("^([%w%-]+)%.%s*$")
        end
        if p and not p:find("SECTION") and not p:find("DIVISION") and not p:match("^END%-") and p ~= "EXIT" and p ~= "FILE-CONTROL" then
          para = p
        end
      end
    end

    if div then
      break
    end
  end

  div = div or "COBOL"
  local parts = {}
  local hl_group = "CobolBreadcrumbProc"

  if div == "PROCEDURE" then
    hl_group = "CobolBreadcrumbProc"
    table.insert(parts, "PROCEDURE")
    if sec then
      table.insert(parts, (sec:gsub("%-SECTION$", "")))
    end
    if para then
      table.insert(parts, para)
    end
  elseif div == "DATA" then
    hl_group = "CobolBreadcrumbData"
    table.insert(parts, "DATA")
    if sec then
      table.insert(parts, (sec:gsub("%-SECTION$", "")))
    end

    -- 如果光标正在某字段上，显示其数据层级路径 (01 RECORD > 05 FIELD > 88 COND)
    local cur_lvl, cur_name = current_line:match("^%s*(%d%d)%s+([%w%-]+)")
    if cur_lvl then
      local target_lvl = tonumber(cur_lvl)
      local data_trail = { cur_lvl .. " " .. cur_name }
      for j = cursor_row - 1, 1, -1 do
        local l = lines[j]
        local lvl_str, name = l:match("^%s*(%d%d)%s+([%w%-]+)")
        if lvl_str then
          local lvl = tonumber(lvl_str)
          if lvl < target_lvl then
            table.insert(data_trail, 1, name)
            target_lvl = lvl
            if lvl == 1 then
              break
            end
          end
        end
        if l:find("SECTION%s*%.") or l:find("DIVISION%s*%.") then
          break
        end
      end
      if #data_trail > 0 then
        table.insert(parts, table.concat(data_trail, " > "))
      end
    end
  elseif div == "ENVIRONMENT" then
    hl_group = "CobolBreadcrumbEnv"
    table.insert(parts, "ENV")
    if sec then
      table.insert(parts, (sec:gsub("%-SECTION$", "")))
    end
  elseif div == "IDENTIFICATION" then
    hl_group = "CobolBreadcrumbId"
    table.insert(parts, "IDENT")
    local prog_id = nil
    for _, l in ipairs(lines) do
      local p = l:match("PROGRAM%-ID%s*%.%s*([%w%-]+)")
      if p then
        prog_id = p
        break
      end
    end
    if prog_id then
      table.insert(parts, prog_id)
    end
  else
    table.insert(parts, div)
  end

  return table.concat(parts, " > "), hl_group
end

-- 动态计算并返回 Winbar 标尺 + 面包屑字符串（精准对齐代码列）
function M.get_winbar()
  if not M.state.enabled or not M.config.show_winbar then
    return ""
  end

  local win_id = vim.api.nvim_get_current_win()
  local ok, wininfo = pcall(vim.fn.getwininfo, win_id)
  local textoff = 0
  if ok and wininfo and wininfo[1] then
    textoff = wininfo[1].textoff or 0
  end

  -- 左侧补充与行号/符号列等宽的空格，确保刻度与代码列 100% 垂直对应
  local pad = string.rep(" ", textoff)

  -- 80 列穿孔卡标尺结构：
  -- 1-6  : SEQ (6 chars)
  -- 7    : IND (1 char: *)
  -- 8-11 : AREA A (4 chars: A...)
  -- 12-72: AREA B (61 chars: B .. 58 dots .. 72)
  -- 73-80: IDENT (8 chars: IDENT...)
  local ruler_parts = {
    "%#CobolRulerBase#" .. pad,
    "%#CobolRulerSeq#..SEQ.",
    "%#CobolRulerInd#*",
    "%#CobolRulerAreaA#A...",
    "%#CobolRulerAreaB#B",
    string.rep(".", 58),
    "72",
    "%#CobolRulerIdent#IDENT...",
  }

  -- 如果开启了面包屑，在标尺右侧追加实时结构路径
  if M.config.show_breadcrumbs then
    local bufnr = vim.api.nvim_win_get_buf(win_id)
    local cursor_row = vim.api.nvim_win_get_cursor(win_id)[1]
    local crumb, hl_group = M.get_breadcrumb(bufnr, cursor_row)
    if crumb and crumb ~= "" then
      table.insert(ruler_parts, "  %#" .. hl_group .. "# [ " .. crumb .. " ]")
    end
  end

  table.insert(ruler_parts, "%#Normal#")
  return table.concat(ruler_parts)
end

-- 更新 DATA DIVISION 当前光标行的宿主回溯虚拟提示 (← 05 PARENT)
function M.update_hierarchy_hint(bufnr, win_id)
  if not M.state.enabled or not M.config.show_hierarchy_hint then
    return
  end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  win_id = win_id or vim.api.nvim_get_current_win()

  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_hint, 0, -1)

  local pos = vim.api.nvim_win_get_cursor(win_id)
  local row = pos[1]
  local line = vim.api.nvim_get_current_line()

  local cur_lvl, cur_name = line:match("^%s*(%d%d)%s+([%w%-]+)")
  if not cur_lvl then
    return
  end

  local lvl_num = tonumber(cur_lvl)
  -- 仅对从属级别（88 或 02-49）寻找并展示上级结构
  if lvl_num == 1 or lvl_num == 77 then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row - 1, false)
  local parent_item, root_item
  local target_lvl = lvl_num

  for i = #lines, 1, -1 do
    local l = lines[i]
    local l_num_str, l_name = l:match("^%s*(%d%d)%s+([%w%-]+)")
    if l_num_str then
      local l_num = tonumber(l_num_str)
      if l_num < target_lvl then
        if not parent_item then
          parent_item = l_num_str .. " " .. l_name
        end
        if l_num == 1 then
          root_item = "01 " .. l_name
          break
        end
        target_lvl = l_num
      end
    end
    if l:find("SECTION%s*%.") or l:find("DIVISION%s*%.") then
      break
    end
  end

  if parent_item then
    local hint_text = "  ← " .. parent_item
    if root_item and root_item ~= parent_item then
      hint_text = hint_text .. " (" .. root_item .. ")"
    end

    pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns_hint, row - 1, 0, {
      virt_text = { { hint_text, "CobolHierarchyHint" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end
end

-- 清除缓冲区的匹配高亮
local function clear_matches(win_id)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    local w = vim.w[win_id]
    if w.cobol_overflow_match then
      pcall(vim.fn.matchdelete, w.cobol_overflow_match, win_id)
      w.cobol_overflow_match = nil
    end
    if w.cobol_lvl88_match then
      pcall(vim.fn.matchdelete, w.cobol_lvl88_match, win_id)
      w.cobol_lvl88_match = nil
    end
    if w.cobol_cond_match then
      pcall(vim.fn.matchdelete, w.cobol_cond_match, win_id)
      w.cobol_cond_match = nil
    end
    if w.cobol_lvl01_match then
      pcall(vim.fn.matchdelete, w.cobol_lvl01_match, win_id)
      w.cobol_lvl01_match = nil
    end
  end
end

-- 设置匹配高亮（72列越界 + Level 88 + Level 01）
local function setup_matches(win_id)
  if not M.state.enabled or not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  clear_matches(win_id)

  -- 1. 72 列越界检测
  if M.config.highlight_overflow then
    local pattern_overflow = [[^.\{6}[^*/].\{-}\%>72v\S\+]]
    local ok, id = pcall(vim.fn.matchadd, "CobolColumnOverflow", pattern_overflow, 15, -1, { window = win_id })
    if ok and id then
      vim.w[win_id].cobol_overflow_match = id
    end
  end

  -- 2. Level 88 与 01 级结构高亮
  if M.config.highlight_levels then
    -- 88 级标志（优先于常规代码行）
    local ok1, id1 = pcall(vim.fn.matchadd, "CobolLevel88", [[\<88\>]], 22, -1, { window = win_id })
    if ok1 and id1 then
      vim.w[win_id].cobol_lvl88_match = id1
    end

    -- 88 级条件名 (例如 88 EOF-YES)
    local ok2, id2 = pcall(vim.fn.matchadd, "CobolConditionName", [[\%(\<88\>\s\+\)\@<=[A-Za-z0-9\-]\+]], 22, -1, { window = win_id })
    if ok2 and id2 then
      vim.w[win_id].cobol_cond_match = id2
    end

    -- 01 顶级记录号
    local ok3, id3 = pcall(vim.fn.matchadd, "CobolLevel01", [[\<01\>\ze\s\+[A-Za-z0-9\-]\+]], 22, -1, { window = win_id })
    if ok3 and id3 then
      vim.w[win_id].cobol_lvl01_match = id3
    end
  end
end

-- 快捷跳转到指定列（1-based）
function M.jump_to_col(target_col)
  local pos = vim.api.nvim_win_get_cursor(0)
  local row = math.max(1, pos[1])
  local line = vim.api.nvim_get_current_line()
  local len = #line

  -- 若当前行短于目标列，补足空格让光标顺利定位
  if len < target_col - 1 then
    local pad = string.rep(" ", (target_col - 1) - len)
    line = line .. pad
    vim.api.nvim_set_current_line(line)
  end

  local target_byte_col = math.max(0, target_col - 1)
  pcall(vim.api.nvim_win_set_cursor, 0, { row, target_byte_col })
end

-- 智能第 7 列注释切换（支持单行及 Visual 模式多行）
function M.toggle_comment(line1, line2)
  line1 = line1 or vim.api.nvim_win_get_cursor(0)[1]
  line2 = line2 or line1
  local bufnr = vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
  local new_lines = {}

  -- 检查所选行是否大部分已是注释
  local all_commented = true
  for _, line in ipairs(lines) do
    if #line >= 7 then
      local ind = line:sub(7, 7)
      if ind ~= "*" and ind ~= "/" then
        all_commented = false
        break
      end
    else
      all_commented = false
      break
    end
  end

  for _, line in ipairs(lines) do
    local new_line = line
    if #new_line < 6 then
      new_line = new_line .. string.rep(" ", 6 - #new_line)
    end

    if all_commented then
      -- 取消注释：第 7 列设为空格
      if #new_line >= 7 then
        new_line = new_line:sub(1, 6) .. " " .. new_line:sub(8)
      end
    else
      -- 添加注释：第 7 列设为 *
      if #new_line == 6 then
        new_line = new_line .. "*"
      else
        new_line = new_line:sub(1, 6) .. "*" .. new_line:sub(8)
      end
    end
    table.insert(new_lines, new_line)
  end

  vim.api.nvim_buf_set_lines(bufnr, line1 - 1, line2, false, new_lines)
end

-- 智能 Tab 键处理（Insert 模式下快速对齐到 Area A 或 Area B）
function M.smart_tab()
  local cursor_col = vim.fn.col(".") -- 1-indexed
  if cursor_col <= 6 then
    -- 跳到第 8 列（Area A 起始）
    local spaces = 8 - cursor_col
    return string.rep(" ", spaces)
  elseif cursor_col >= 7 and cursor_col <= 11 then
    -- 跳到第 12 列（Area B 起始）
    local spaces = 12 - cursor_col
    return string.rep(" ", spaces)
  else
    -- 正常 Tab（空格）
    local sw = vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or 4
    return string.rep(" ", sw)
  end
end

-- 挂载到 COBOL 缓冲区
function M.attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  setup_folding(bufnr)

  -- 设置贯穿标尺：默认关闭 colorcolumn 背景色块；仅当显式要求时才开启
  vim.b[bufnr].cobol_orig_colorcolumn = vim.opt_local.colorcolumn:get()
  if M.config.show_colorcolumn and M.state.enabled then
    vim.opt_local.colorcolumn = table.concat(M.config.columns, ",")
  else
    vim.opt_local.colorcolumn = ""
  end

  -- 激活 Winbar 标尺与面包屑
  if M.config.show_winbar and M.state.enabled then
    vim.b[bufnr].cobol_orig_winbar = vim.wo.winbar
    vim.wo.winbar = "%!v:lua.require'cobol'.get_winbar()"
  end

  -- 禁用当前 COBOL 缓冲区的通用缩进线（如 indent-blankline）
  if M.config.disable_indent_guide then
    local ok_ibl, ibl = pcall(require, "ibl")
    if ok_ibl and ibl.setup_buffer then
      pcall(ibl.setup_buffer, bufnr, { enabled = false })
    end
  end

  -- 设置匹配高亮
  local win_id = vim.api.nvim_get_current_win()
  setup_matches(win_id)

  -- 更新宿主回溯提示
  M.update_hierarchy_hint(bufnr, win_id)
  if M.config.show_pic_size then
    local ok_calc, calc = pcall(require, "cobol.calculator")
    if ok_calc and calc.update_cursor_hint then
      calc.update_cursor_hint(bufnr, win_id)
    end
  end

  -- 注册快捷键
  if M.config.keymaps then
    local ok_nav, nav = pcall(require, "cobol.navigation")
    if ok_nav and nav.setup_keymaps then
      nav.setup_keymaps(bufnr)
    end

    local ok_calc, calc = pcall(require, "cobol.calculator")
    if ok_calc and calc.setup_keymaps then
      calc.setup_keymaps(bufnr)
    end

    local ok_diag, diag = pcall(require, "cobol.diagnostics")
    if ok_diag and diag.setup_keymaps then
      diag.setup_keymaps(bufnr)
    end

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end

    -- 列跳转快捷键
    map("n", "g7", function() M.jump_to_col(7) end, "COBOL: Jump to Indicator (Col 7)")
    map("n", "g8", function() M.jump_to_col(8) end, "COBOL: Jump to Area A (Col 8)")
    map("n", "g12", function() M.jump_to_col(12) end, "COBOL: Jump to Area B (Col 12)")
    map("n", "g73", function() M.jump_to_col(73) end, "COBOL: Jump to Identification (Col 73)")

    -- 第 7 列注释切换快捷键
    map("n", "gcc", function() M.toggle_comment() end, "COBOL: Toggle Col 7 Comment (*)")
    map("n", "<leader>c*", function() M.toggle_comment() end, "COBOL: Toggle Col 7 Comment (*)")
    map("x", "<leader>c*", function()
      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      M.toggle_comment(start_line, end_line)
    end, "COBOL: Toggle Col 7 Comment on Selection")

    -- 智能 Tab（仅当行首或前导空白时生效）
    if M.config.smart_tab then
      vim.keymap.set("i", "<Tab>", function()
        local line = vim.api.nvim_get_current_line()
        local col = vim.fn.col(".") - 1
        local before = line:sub(1, col)
        if before:match("^%s*$") then
          return M.smart_tab()
        end
        return "<Tab>"
      end, { buffer = bufnr, expr = true, silent = true, desc = "COBOL: Smart Align Tab" })
    end
  end

  -- 首次载入时触发异步语法飞检
  local diag_cfg = (M.config and M.config.diagnostics) or {}
  if diag_cfg.enable then
    local ok_diag, diag = pcall(require, "cobol.diagnostics")
    if ok_diag and diag.lint then
      diag.lint(bufnr)
    end
  end
end

-- 从缓冲区卸载
function M.detach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- 还原 colorcolumn
  local orig_cc = vim.b[bufnr].cobol_orig_colorcolumn
  if orig_cc ~= nil then
    vim.opt_local.colorcolumn = orig_cc
  else
    vim.opt_local.colorcolumn = ""
  end

  -- 还原 winbar
  local orig_wb = vim.b[bufnr].cobol_orig_winbar
  if orig_wb ~= nil then
    vim.wo.winbar = orig_wb
  else
    vim.wo.winbar = ""
  end

  -- 还原 indent-blankline
  if M.config.disable_indent_guide then
    local ok_ibl, ibl = pcall(require, "ibl")
    if ok_ibl and ibl.setup_buffer then
      pcall(ibl.setup_buffer, bufnr, { enabled = true })
    end
  end

  -- 清除匹配高亮与提示
  local win_id = vim.api.nvim_get_current_win()
  clear_matches(win_id)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_hint, 0, -1)
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, vim.api.nvim_create_namespace("cobol_nvim_calc"), 0, -1)

  -- 清除诊断与任务
  local ok_diag, diag = pcall(require, "cobol.diagnostics")
  if ok_diag and diag.clear then
    diag.clear(bufnr)
  end
end

-- 全局开启
function M.enable()
  M.state.enabled = true
  M.setup_highlights()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft == "cobol" or ft == "cbl" or ft == "cob" then
      M.attach(buf)
    end
  end
  vim.cmd("redraw")
  vim.notify("cobol.nvim: Enabled", vim.log.levels.INFO)
end

-- 全局关闭
function M.disable()
  M.state.enabled = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft == "cobol" or ft == "cbl" or ft == "cob" then
      M.detach(buf)
    end
  end
  vim.cmd("redraw")
  vim.notify("cobol.nvim: Disabled", vim.log.levels.INFO)
end

-- 开关切换
function M.toggle()
  if M.state.enabled then
    M.disable()
  else
    M.enable()
  end
end

-- 注册基于虚拟文本的细线标尺 Decoration Provider
local function setup_line_ruler()
  vim.api.nvim_set_decoration_provider(M.ns_ruler, {
    on_win = function(_, win, buf, toprow, botrow)
      if not M.state.enabled or not M.config.show_lines then
        return false
      end
      if not vim.api.nvim_buf_is_valid(buf) then
        return false
      end
      local ft = vim.bo[buf].filetype
      if ft ~= "cobol" and ft ~= "cbl" and ft ~= "cob" then
        return false
      end
      return true
    end,
    on_line = function(_, win, buf, row)
      local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
      if not lines or #lines == 0 then
        return
      end
      local line = lines[1]
      local line_len = #line
      local char = M.config.char or "│"

      for _, col in ipairs(M.config.columns) do
        local should_draw = false
        if line_len < col then
          should_draw = true
        else
          local b = line:byte(col)
          if b == 32 or b == 9 then
            should_draw = true
          end
        end

        if should_draw then
          local hl = (col == 7) and "CobolRulerLineInd" or "CobolRulerLine"
          vim.api.nvim_buf_set_extmark(buf, M.ns_ruler, row, 0, {
            virt_text = { { char, hl } },
            virt_text_win_col = col - 1,
            ephemeral = true,
          })
        end
      end
    end,
  })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  local ok_contextline, contextline = pcall(require, "contextline")
  if ok_contextline then
    contextline.register("cobol", {
      filetypes = { "cobol", "cbl", "cob" },
      get_info = require("cobol.context").get_info,
    })
  end
  M.setup_highlights()
  setup_line_ruler()

  -- 创建用户命令
  vim.api.nvim_create_user_command("CobolGuideToggle", function()
    M.toggle()
  end, { desc = "Toggle COBOL fixed-format guide" })

  vim.api.nvim_create_user_command("CobolGuideEnable", function()
    M.enable()
  end, { desc = "Enable COBOL fixed-format guide" })

  vim.api.nvim_create_user_command("CobolGuideDisable", function()
    M.disable()
  end, { desc = "Disable COBOL fixed-format guide" })

  vim.api.nvim_create_user_command("CobolToggleComment", function(args)
    M.toggle_comment(args.line1, args.line2)
  end, { range = true, desc = "Toggle column 7 comment (*)" })

  vim.api.nvim_create_user_command("CobolGotoDef", function()
    require("cobol.navigation").goto_definition()
  end, { desc = "COBOL: Jump to definition (paragraph/data)" })

  vim.api.nvim_create_user_command("CobolGotoCopybook", function()
    require("cobol.navigation").goto_copybook()
  end, { desc = "COBOL: Open copybook file" })

  vim.api.nvim_create_user_command("CobolPreview", function()
    require("cobol.navigation").hover_preview()
  end, { desc = "COBOL: Preview definition or copybook under cursor" })

  vim.api.nvim_create_user_command("CobolCalcRecord", function()
    require("cobol.calculator").show_record_layout()
  end, { desc = "COBOL: Calculate memory layout and total byte size of 01 record" })

  vim.api.nvim_create_user_command("CobolFormatCase", function(args)
    local start_line = args.line1
    local end_line = args.line2
    if args.range == 0 then
      start_line = 1
      end_line = vim.api.nvim_buf_line_count(0)
    end
    local changed = require("cobol.formatter").format_range(0, start_line, end_line)
    vim.notify(string.format("COBOL: formatted %d line(s)", changed), vim.log.levels.INFO)
  end, { range = true, desc = "COBOL: Uppercase reserved words" })

  vim.api.nvim_create_user_command("CobolLint", function()
    require("cobol.diagnostics").lint(nil, { interactive = true })
  end, { desc = "COBOL: Run real-time GnuCOBOL syntax check (cobc)" })

  vim.api.nvim_create_user_command("CobolQuickfix", function()
    require("cobol.diagnostics").open_quickfix()
  end, { desc = "COBOL: Open diagnostics Quickfix list" })

  vim.api.nvim_create_user_command("CobolDiagnosticsToggle", function()
    if M.config.diagnostics then
      M.config.diagnostics.enable = not M.config.diagnostics.enable
      local status = M.config.diagnostics.enable and "Enabled" or "Disabled"
      if not M.config.diagnostics.enable then
        require("cobol.diagnostics").clear()
      else
        require("cobol.diagnostics").lint(nil, { interactive = true })
      end
      vim.notify("COBOL Diagnostics: " .. status, vim.log.levels.INFO)
    end
  end, { desc = "COBOL: Toggle GnuCOBOL diagnostics linter" })

  -- 针对 COBOL 文件类型的自动命令
  local group = vim.api.nvim_create_augroup("CobolNvimGroup", { clear = true })

  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = group,
    pattern = { "cobol", "cbl", "cob" },
    callback = function(ev)
      M.attach(ev.buf)
    end,
  })

  -- blink.cmp is commonly lazy-loaded on InsertEnter. Register here and
  -- retry at InsertEnter so the plugin remains optional and load-order safe.
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      M.register_completion()
    end,
  })
  M.register_completion()

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype
      if ft == "cobol" or ft == "cbl" or ft == "cob" then
        local win_id = vim.api.nvim_get_current_win()
        setup_matches(win_id)
        M.update_hierarchy_hint(ev.buf, win_id)
        if M.config.show_pic_size then
          local ok_calc, calc = pcall(require, "cobol.calculator")
          if ok_calc and calc.update_cursor_hint then
            calc.update_cursor_hint(ev.buf, win_id)
          end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype
      if ft == "cobol" or ft == "cbl" or ft == "cob" then
        local win_id = vim.api.nvim_get_current_win()
        M.update_hierarchy_hint(ev.buf, win_id)
        if M.config.show_pic_size then
          local ok_calc, calc = pcall(require, "cobol.calculator")
          if ok_calc and calc.update_cursor_hint then
            calc.update_cursor_hint(ev.buf, win_id)
          end
        end
      end
    end,
  })

  -- 异步语法飞检触发事件
  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    group = group,
    pattern = { "*.cob", "*.cbl", "*.cpy", "*.COB", "*.CBL", "*.CPY" },
    callback = function(ev)
      local diag_cfg = (M.config and M.config.diagnostics) or {}
      if diag_cfg.enable and diag_cfg.on_save then
        local ok_diag, diag = pcall(require, "cobol.diagnostics")
        if ok_diag and diag.lint then
          diag.lint(ev.buf)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype
      if ft == "cobol" or ft == "cbl" or ft == "cob" then
        local diag_cfg = (M.config and M.config.diagnostics) or {}
        if diag_cfg.enable and diag_cfg.on_change then
          local ok_diag, diag = pcall(require, "cobol.diagnostics")
          if ok_diag and diag.lint_debounced then
            diag.lint_debounced(ev.buf)
          end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = group,
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype
      if ft == "cobol" or ft == "cbl" or ft == "cob" then
        local diag_cfg = (M.config and M.config.diagnostics) or {}
        if diag_cfg.enable and diag_cfg.on_change then
          local ok_diag, diag = pcall(require, "cobol.diagnostics")
          if ok_diag and diag.lint then
            diag.lint(ev.buf)
          end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "ColorScheme" }, {
    group = group,
    callback = function()
      M.setup_highlights()
    end,
  })

  local current_buf = vim.api.nvim_get_current_buf()
  local current_ft = vim.bo[current_buf].filetype
  if current_ft == "cobol" or current_ft == "cbl" or current_ft == "cob" then
    M.attach(current_buf)
  end
end

return M
