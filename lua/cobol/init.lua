-- lua/cobol/init.lua
-- cobol.nvim: Modern COBOL development & visual enhancement toolkit for Neovim

local M = {}

local default_config = {
  enabled = true,
  columns = { 7, 8, 12, 73 }, -- 标尺列：7 (Ind), 8 (Area A), 12 (Area B), 73 (Past Area B)
  show_lines = true,          -- 使用纯字符细线标尺 (│)，零背景色
  char = "│",                 -- 细线字符 (U+2502)
  show_winbar = true,         -- 顶部打孔卡刻度
  show_colorcolumn = false,   -- 禁用粗背景色块
  highlight_overflow = true,  -- 72 列越界代码告警
  overflow_col = 72,
  disable_indent_guide = true,-- 自动禁用当前 COBOL buffer 的通用缩进线（如 ibl）
  smart_tab = true,           -- 智能对齐 Tab
  smart_comments = true,      -- 第 7 列智能注释切换
  keymaps = true,             -- 默认快捷键
}

M.config = vim.deepcopy(default_config)
M.state = {
  enabled = true,
}

M.ns_ruler = vim.api.nvim_create_namespace("cobol_nvim_ruler")

-- 初始化高亮组（融入 Fresh / Catppuccin / High Contrast 配色）
function M.setup_highlights()
  local set = function(group, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- 纯细线标尺配色：无背景色，使用清爽的淡钢蓝/冷灰前景色，与缩进线风格融合
  set("CobolRulerLine", { fg = "#3b638c", bg = "NONE" })
  set("CobolRulerLineInd", { fg = "#4c78a8", bg = "NONE" })

  -- Winbar 各区域配色
  set("CobolRulerBase", { fg = "#5c6370", bg = "#181c24" })
  set("CobolRulerSeq", { fg = "#6b7280", bg = "#181c24" })
  set("CobolRulerInd", { fg = "#e5c07b", bg = "#222730", bold = true })
  set("CobolRulerAreaA", { fg = "#61afef", bg = "#1f2735", bold = true })
  set("CobolRulerAreaB", { fg = "#98c379", bg = "#181c24" })
  set("CobolRulerIdent", { fg = "#e06c75", bg = "#251d22" })

  -- 72 列越界代码高亮（醒目告警）
  set("CobolColumnOverflow", {
    fg = "#ff7b72",
    bg = "#382024",
    undercurl = true,
    sp = "#ff7b72",
    bold = true,
  })

  -- 兼容备用 ColorColumn（默认不使用）
  set("CobolRulerCol", {
    bg = "#232832",
  })
end

-- 动态计算并返回 Winbar 标尺字符串（精准对齐代码列）
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
  local ruler = table.concat({
    "%#CobolRulerBase#" .. pad,
    "%#CobolRulerSeq#..SEQ.",
    "%#CobolRulerInd#*",
    "%#CobolRulerAreaA#A...",
    "%#CobolRulerAreaB#B",
    string.rep(".", 58),
    "72",
    "%#CobolRulerIdent#IDENT...",
    "%#Normal#",
  })

  return ruler
end

-- 清除缓冲区的越界高亮
local function clear_overflow(bufnr, win_id)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    local match_id = vim.w[win_id].cobol_overflow_match
    if match_id then
      pcall(vim.fn.matchdelete, match_id, win_id)
      vim.w[win_id].cobol_overflow_match = nil
    end
  end
end

-- 添加第 72 列越界检测（非注释行超过 72 列的代码）
local function setup_overflow(win_id)
  if not M.state.enabled or not M.config.highlight_overflow then
    return
  end
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  clear_overflow(nil, win_id)

  -- 正则解释：
  -- ^.\{6}[^*/] -> 第 7 列不是 * 或 /（排除整行注释）
  -- .\{-}\%>72v\S\+ -> 在第 72 屏幕列之后出现的非空代码字符
  local pattern = [[^.\{6}[^*/].\{-}\%>72v\S\+]]
  local ok, match_id = pcall(vim.fn.matchadd, "CobolColumnOverflow", pattern, 15, -1, { window = win_id })
  if ok and match_id then
    vim.w[win_id].cobol_overflow_match = match_id
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

  -- 设置贯穿标尺：默认关闭 colorcolumn 背景色块；仅当显式要求时才开启
  vim.b[bufnr].cobol_orig_colorcolumn = vim.opt_local.colorcolumn:get()
  if M.config.show_colorcolumn and M.state.enabled then
    vim.opt_local.colorcolumn = table.concat(M.config.columns, ",")
  else
    vim.opt_local.colorcolumn = ""
  end

  -- 激活 Winbar 标尺
  if M.config.show_winbar and M.state.enabled then
    vim.b[bufnr].cobol_orig_winbar = vim.wo.winbar
    vim.wo.winbar = "%!v:lua.require'cobol'.get_winbar()"
  end

  -- 禁用当前 COBOL 缓冲区的通用缩进线（如 indent-blankline），防止通用缩进线与 COBOL 标尺重叠干扰
  if M.config.disable_indent_guide then
    local ok_ibl, ibl = pcall(require, "ibl")
    if ok_ibl and ibl.setup_buffer then
      pcall(ibl.setup_buffer, bufnr, { enabled = false })
    end
  end

  -- 设置越界高亮
  local win_id = vim.api.nvim_get_current_win()
  setup_overflow(win_id)

  -- 注册快捷键
  if M.config.keymaps then
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end

    -- 列跳转快捷键
    map("n", "g7", function() M.jump_to_col(7) end, "COBOL: Jump to Indicator (Col 7)")
    map("n", "g8", function() M.jump_to_col(8) end, "COBOL: Jump to Area A (Col 8)")
    map("n", "g12", function() M.jump_to_col(12) end, "COBOL: Jump to Area B (Col 12)")
    map("n", "g73", function() M.jump_to_col(73) end, "COBOL: Jump to Identification (Col 73)")

    -- 第 7 列注释切换快捷键
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

  -- 清除越界告警
  local win_id = vim.api.nvim_get_current_win()
  clear_overflow(bufnr, win_id)
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
  vim.notify("cobol.nvim: Enabled (Lines │ at cols 7, 8, 12, 73)", vim.log.levels.INFO)
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

-- 注册基于虚拟文本的细线标尺 Decoration Provider（高性能视口渲染，零背景色）
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
          -- 短行或空行：在虚空列处绘制细线
          should_draw = true
        else
          local b = line:byte(col)
          -- 所在列为前导空格或制表符时绘制细线，遇到代码字符则自动让位不遮挡
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

-- 插件 setup 入口
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
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

  -- 针对 COBOL 文件类型的自动命令
  local group = vim.api.nvim_create_augroup("CobolNvimGroup", { clear = true })

  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = group,
    pattern = { "cobol", "cbl", "cob" },
    callback = function(ev)
      M.attach(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype
      if ft == "cobol" or ft == "cbl" or ft == "cob" then
        setup_overflow(vim.api.nvim_get_current_win())
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "ColorScheme" }, {
    group = group,
    callback = function()
      M.setup_highlights()
    end,
  })
end

return M
