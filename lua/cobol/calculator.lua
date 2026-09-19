-- lua/cobol/calculator.lua
-- cobol.nvim: PIC clause size calculator & 01 Record byte layout analyzer

local M = {}

M.ns_calc = vim.api.nvim_create_namespace("cobol_nvim_calc")

-- 展开 PIC 重复简写，例如 X(20) -> 20 个 X, 9(5)V99 -> 99999V99
function M.expand_pic(pic_str)
  if not pic_str or pic_str == "" then
    return ""
  end
  pic_str = pic_str:upper()
  local expanded = pic_str:gsub("([X9AZS$*+,-])%((%d+)%)", function(char, count)
    return string.rep(char, tonumber(count))
  end)
  return expanded
end

-- 解析单行数据项定义，计算其占用字节数
function M.parse_field_size(raw_line)
  if not raw_line or raw_line == "" then
    return nil
  end
  local upper = raw_line:upper()

  -- 过滤注释行与 88 级条件名（88 级不占空间）
  if raw_line:match("^%s*88%s+") then
    return nil
  end
  if #raw_line >= 7 and (raw_line:sub(7, 7) == "*" or raw_line:sub(7, 7) == "/") then
    return nil
  end

  local lvl_str, name = upper:match("^%s*(%d%d)%s+([%w%-]+)")
  if not lvl_str then
    return nil
  end

  local level = tonumber(lvl_str)
  local redefines = upper:match("REDEFINES%s+([%w%-]+)")
  local occurs_str = upper:match("OCCURS%s+(%d+)")
  local occurs = occurs_str and tonumber(occurs_str) or 1

  -- 提取 PIC 描述
  local pic = upper:match("[Pp][Ii][Cc]%s+IS%s+([A-Za-z0-9%(%)]+)")
    or upper:match("[Pp][Ii][Cc]%s+([A-Za-z0-9%(%)]+)")
    or upper:match("[Pp][Ii][Cc][Tt][Uu][Rr][Ee]%s+IS%s+([A-Za-z0-9%(%)]+)")
    or upper:match("[Pp][Ii][Cc][Tt][Uu][Rr][Ee]%s+([A-Za-z0-9%(%)]+)")

  -- 若没有 PIC，说明是组项（Group Item，由从属字段提供具体空间）
  if not pic then
    return {
      level = level,
      name = name,
      is_group = true,
      occurs = occurs,
      redefines = redefines,
      bytes = 0,
    }
  end

  -- 判断 USAGE（存储模式）
  local usage = "DISPLAY"
  if upper:find("COMP%-3") or upper:find("PACKED%-DECIMAL") then
    usage = "COMP-3"
  elseif upper:find("COMP%-4") or upper:find("COMP%-5") or upper:find("COMP") or upper:find("BINARY") then
    usage = "COMP"
  elseif upper:find("COMP%-1") then
    usage = "COMP-1"
  elseif upper:find("COMP%-2") then
    usage = "COMP-2"
  elseif upper:find("POINTER") then
    usage = "POINTER"
  end

  local expanded = M.expand_pic(pic)
  local bytes = 0
  local has_separate_sign = upper:find("SEPARATE") ~= nil

  if usage == "COMP-3" then
    -- Packed-Decimal: 每个数字半字节(4bit)，末尾符号半字节，公式 ceil((digits + 1) / 2)
    local _, digits = expanded:gsub("9", "")
    bytes = math.ceil((digits + 1) / 2)
  elseif usage == "COMP" then
    -- Binary: 1-4位占2字节(Halfword)，5-9位占4字节(Fullword)，10-18位占8字节(Doubleword)
    local _, digits = expanded:gsub("9", "")
    if digits <= 4 then
      bytes = 2
    elseif digits <= 9 then
      bytes = 4
    else
      bytes = 8
    end
  elseif usage == "COMP-1" then
    bytes = 4 -- 单精度浮点
  elseif usage == "COMP-2" then
    bytes = 8 -- 双精度浮点
  elseif usage == "POINTER" then
    bytes = 8 -- 64位指针
  else
    -- 常规 DISPLAY 文本显示格式
    for i = 1, #expanded do
      local c = expanded:sub(i, i)
      if c == "V" then
        -- 隐式小数点不占物理存储空间
      elseif c == "S" then
        if has_separate_sign then
          bytes = bytes + 1
        end
      else
        bytes = bytes + 1
      end
    end
  end

  bytes = bytes * occurs

  return {
    level = level,
    name = name,
    pic = pic,
    usage = usage,
    occurs = occurs,
    redefines = redefines,
    is_group = false,
    bytes = bytes,
  }
end

-- 向上扫描定位当前行所属的 01 记录起始行号
function M.find_enclosing_record_start(bufnr, cursor_row)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor_row, false)

  for i = #lines, 1, -1 do
    local l = lines[i]
    if l:match("^%s*01%s+[%w%-]+") then
      return i
    end
    -- 如果越过数据部节或部声明，终止
    local upper = l:upper()
    if upper:find("SECTION%s*%.") or upper:find("DIVISION%s*%.") then
      break
    end
  end
  return nil
end

-- 递归分析并汇总指定 01 记录的数据布局与总大小
function M.calculate_record(bufnr, start_row)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local start_line = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, start_row, false)[1] or ""

  local root = M.parse_field_size(start_line)
  if not root or root.level ~= 1 then
    return nil
  end

  local total_bytes = 0
  local fields = {}

  -- 若 01 自身就是基本项（例如 01 INPUT-RECORD PIC X(256).）
  if not root.is_group then
    total_bytes = root.bytes
    table.insert(fields, {
      name = root.name,
      level = root.level,
      pic = root.pic,
      usage = root.usage,
      bytes = root.bytes,
      offset = 0,
      line = start_row,
    })
    return {
      root_name = root.name,
      line = start_row,
      total_bytes = total_bytes,
      fields = fields,
    }
  end

  -- 若为包含多字段的组记录，向下扫描子字段
  local cur_offset = 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, total_lines, false)

  for idx, raw in ipairs(lines) do
    local cur_line_num = start_row + idx
    local upper = raw:upper()
    if upper:find("SECTION%s*%.") or upper:find("DIVISION%s*%.") then
      break
    end

    local item = M.parse_field_size(raw)
    if item then
      -- 遇到下一个 01 或 77 独立项时终止
      if item.level == 1 or item.level == 77 then
        break
      end

      if not item.is_group then
        if not item.redefines then
          table.insert(fields, {
            name = item.name,
            level = item.level,
            pic = item.pic,
            usage = item.usage,
            bytes = item.bytes,
            offset = cur_offset,
            occurs = item.occurs,
            line = cur_line_num,
          })
          cur_offset = cur_offset + item.bytes
          total_bytes = total_bytes + item.bytes
        else
          table.insert(fields, {
            name = item.name,
            level = item.level,
            pic = item.pic,
            usage = item.usage,
            bytes = item.bytes,
            offset = string.format("(=%s)", item.redefines),
            redefines = item.redefines,
            line = cur_line_num,
          })
        end
      end
    end
  end

  return {
    root_name = root.name,
    line = start_row,
    total_bytes = total_bytes,
    fields = fields,
  }
end

-- 更新当前光标行的字节计算虚拟提示
function M.update_cursor_hint(bufnr, win_id)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  win_id = win_id or vim.api.nvim_get_current_win()
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_calc, 0, -1)

  local row = vim.api.nvim_win_get_cursor(win_id)[1]
  local line = vim.api.nvim_get_current_line()

  local upper = line:upper()
  -- 仅在 DATA DIVISION 区域提示
  local item = M.parse_field_size(line)
  if not item then
    return
  end

  if item.level == 1 then
    -- 如果光标在 01 记录行，汇总计算整条记录的总大小
    local rec = M.calculate_record(bufnr, row)
    if rec then
      local count = #rec.fields
      local hint = string.format("  /* Total: %d Bytes (%d fields) */", rec.total_bytes, count)
      pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns_calc, row - 1, 0, {
        virt_text = { { hint, "CobolRecordSizeHint" } },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end
  elseif not item.is_group then
    -- 如果光标在具体数据字段上，提示单项字节与 USAGE
    local usage_desc = (item.usage ~= "DISPLAY") and (" " .. item.usage) or ""
    local occurs_desc = (item.occurs > 1) and string.format(" x%d", item.occurs) or ""
    local hint = string.format("  /* %d B%s%s */", item.bytes, usage_desc, occurs_desc)
    pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns_calc, row - 1, 0, {
      virt_text = { { hint, "CobolSizeHint" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end
end

-- 弹出居中浮动窗口展示完整 Record 字段偏移排布报表
function M.show_record_layout(bufnr, cursor_row)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  cursor_row = cursor_row or vim.api.nvim_win_get_cursor(0)[1]

  local start_row = M.find_enclosing_record_start(bufnr, cursor_row)
  if not start_row then
    vim.notify("COBOL: No enclosing 01 Record found at cursor position", vim.log.levels.WARN)
    return
  end

  local rec = M.calculate_record(bufnr, start_row)
  if not rec then
    vim.notify("COBOL: Failed to analyze record layout", vim.log.levels.WARN)
    return
  end

  -- 构建高质感表格报表
  local lines = {}
  table.insert(lines, string.format(" 📊 Record: %s (Line %d) — Total Size: %d Bytes", rec.root_name, rec.line, rec.total_bytes))
  table.insert(lines, string.rep("─", 72))
  table.insert(lines, string.format(" %-7s │ %-4s │ %-20s │ %-18s │ %-8s", "Offset", "Lvl", "Field Name", "PIC / Usage", "Size"))
  table.insert(lines, string.rep("─", 72))

  for _, f in ipairs(rec.fields) do
    local offset_str = (type(f.offset) == "number") and string.format("+%-5d", f.offset) or f.offset
    local pic_usage = f.pic or ""
    if f.usage and f.usage ~= "DISPLAY" then
      pic_usage = pic_usage .. " (" .. f.usage .. ")"
    end
    table.insert(lines, string.format(" %-7s │ %02d   │ %-20s │ %-18s │ %4d B", offset_str, f.level, f.name, pic_usage, f.bytes))
  end

  table.insert(lines, string.rep("─", 72))
  table.insert(lines, string.format(" Σ Total Fields: %d | Total Length: %d Bytes", #rec.fields, rec.total_bytes))

  local max_len = 0
  for _, l in ipairs(lines) do
    max_len = math.max(max_len, vim.fn.strdisplaywidth(l))
  end
  local width = math.min(math.max(max_len + 4, 60), 96)
  local height = math.min(#lines, 26)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
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
    title = " 📊 COBOL Record Memory Layout ",
    title_pos = "center",
  })

  local close_fn = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close_fn, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close_fn, { buffer = buf, nowait = true, silent = true })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buf,
    once = true,
    callback = close_fn,
  })
end

-- 挂载按键映射
function M.setup_keymaps(bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  -- <leader>cr 或 :CobolCalcRecord：打开当前 Record 的字段内存偏移排布报表
  map("n", "<leader>cr", function() M.show_record_layout(bufnr) end, "COBOL: Calculate Record Layout & Total Size")
end

return M
