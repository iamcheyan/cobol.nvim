# cobol.nvim

Modern COBOL development & visual enhancement toolkit for Neovim.

为 Neovim 打造的现代化 COBOL（Fixed-Format 固定格式）开发与视觉辅助插件。

---

## 特性亮点 (Features)

* 📏 **纯细线标尺（Zero Background Noise）**：
  * 基于 Neovim 原生 `decoration_provider` 与 `virt_text_win_col` 高性能视口渲染。
  * 在第 **7** 列（Indicator）、第 **8** 列（Area A）、第 **12** 列（Area B）、第 **73** 列（Area B 结束）绘制纯细竖线 `│`。
  * **零背景色**，前景色为低对比度淡钢蓝，与代码缩进线浑然一体；遇到文字自动避让，空行短行贯穿整屏。
* 🏷️ **Winbar 动态打孔卡刻度尺（Punch-Card Header）**：
  * 窗口顶部常驻显示 80 列经典穿孔卡刻度：
    ```text
    |--SEQ-|*|-A-|-B----------------------------------------------------|--ID--|
    1......6.7...8.12...................................................72.73....80
    ```
  * 依据 `textoff` 动态左补空格，与下方代码列 **100% 绝对垂直对应**。
* ⚠️ **第 72 列越界安全告警（Overflow Linter）**：
  * 固定格式 COBOL 中，第 73 列以后的字符会被编译器彻底忽略。插件自动用波浪下划线标红超出 72 列的代码字符，防止隐蔽 Bug。
* 💬 **第 7 列智能注释切换**：
  * `<leader>c*` / `:CobolToggleComment`：精准在第 7 列插入或移除 `*` 注释符，支持单行与 Visual 多行选区，绝不破坏原有代码缩进。
* ⚡ **智能 Tab 吸附与列跳转**：
  * 行首缩进时按 Tab：1-6 列自动跳至第 8 列（Area A），7-11 列自动跳至第 12 列（Area B）。
  * 快捷跳转：`g7`（Indicator）、`g8`（Area A）、`g12`（Area B）、`g73`（Identification）。
* 🛡️ **智能屏蔽干扰**：
  * 自动在 COBOL 缓冲区静默通用语言缩进线（`indent-blankline.nvim`），避免多重线条互相冲突。

---

## 安装与配置 (Installation)

### 使用 lazy.nvim

```lua
return {
  {
    "iamcheyan/cobol.nvim", -- 或通过本地私有目录加载
    ft = { "cobol", "cbl", "cob" },
    opts = {
      enabled = true,
      columns = { 7, 8, 12, 73 },
      show_lines = true,         -- 启用细标尺线 (│)
      char = "│",                -- 标尺字符
      show_winbar = true,        -- 顶部打孔卡刻度
      show_colorcolumn = false,  -- 禁用粗背景色块
      highlight_overflow = true, -- 第 72 列越界告警
      overflow_col = 72,
      disable_indent_guide = true,-- 静默通用缩进线
      smart_tab = true,          -- 智能 Tab 对齐
      smart_comments = true,     -- 第 7 列智能注释
      keymaps = true,            -- 注册默认快捷键
    },
    config = function(_, opts)
      require("cobol").setup(opts)
    end,
  },
}
```

---

## 快捷键一览 (Keymaps)

| 快捷键 | 模式 | 功能说明 |
|---|---|---|
| `<leader>uc` | Normal | 一键开关整个 COBOL 标尺与 Winbar 刻度 |
| `<leader>c*` | Normal / Visual | 在第 7 列插入/移除 `*` 注释标记（支持选中多行） |
| `g7` | Normal | 光标直跳第 7 列（Indicator 列） |
| `g8` | Normal | 光标直跳第 8 列（Area A 起始） |
| `g12` | Normal | 光标直跳第 12 列（Area B 起始） |
| `g73` | Normal | 光标直跳第 73 列（Identification 识别区起始） |
| `<Tab>` | Insert | 行首或前导空白处自动吸附到第 8 列或第 12 列 |

---

## 用户命令 (Commands)

* `:CobolGuideToggle` - 切换标尺与 Winbar
* `:CobolGuideEnable` - 开启标尺与 Winbar
* `:CobolGuideDisable` - 关闭标尺与 Winbar
* `:CobolToggleComment` - 在第 7 列切换注释

---

## 路线图与功能验证 (Roadmap & Verification)

详细功能规划、实现规格与测试自检清单请参见 [docs/ROADMAP.md](docs/ROADMAP.md)：
* **Phase 1: 穿孔卡标尺与安全边界**（已完成 ✅）：纯细线标尺、Winbar 刻度、72 列溢出告警、第 7 列注释、快捷跳转与 Tab 吸附。
* **Phase 2.1: 结构大纲与层级展示**（已完成 ✅）：Winbar 段落面包屑、01/88 级高亮与行尾宿主回溯、Aerial 侧边栏 3 层符号树（`<leader>cs`）。
* **Phase 2.2: 代码定义跳转与 Copybook 预览**（优先实施中 📌）：`PERFORM` / `GO TO` 段落一键直达（`gd` / `<C-o>`）、`COPY` Copybook 文件跳转（`gf`）与悬浮窗预览（`K`）。
* **Phase 3: 数据层级与 PIC 结构计算器**（进阶实施 📌）：单项 `PIC` 字节换算、`01 RECORD` 自动递归汇总总字节数。
* **Phase 4: 编译器实时语法飞检**（安全实施 📌）：GnuCOBOL (`cobc -fsyntax-only`) 异步语法飞检与 Diagnostics 映射。
* **Phase 5: 语法折叠与格式化**（优化实施 📌）：Division/Section/Paragraph 语法级折叠（`za`）、保留字大小写规范化。

---

## License

MIT
