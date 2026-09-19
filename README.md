# cobol.nvim

Modern COBOL development & visual enhancement toolkit for Neovim.

为 Neovim 打造的现代化 COBOL（Fixed-Format 固定格式）开发与视觉辅助插件。

---

## 特性亮点 (Features)

* 📏 **纯细线标尺（Zero Background Noise）**：
  * 基于 Neovim 原生 `decoration_provider` 与 `virt_text_win_col` 高性能视口渲染。
  * 在第 **7** 列（Indicator）、第 **8** 列（Area A）、第 **12** 列（Area B）、第 **73** 列（Area B 结束）绘制纯细竖线 `│`。
  * **零背景色**，前景色为低对比度淡钢蓝，与代码缩进线浑然一体；遇到文字自动避让，空行短行贯穿整屏。
* 🏷️ **Winbar 动态打孔卡刻度尺与实时面包屑**：
  * 窗口顶部常驻显示 80 列经典穿孔卡刻度：
    ```text
    ..SEQ.*A...B..........................................72IDENT... [ PROCEDURE > 2000-PROCESS ]
    ```
  * 依据 `textoff` 动态左补空格，与下方代码列 **100% 绝对垂直对应**；右侧动态展示架构路径。
* ⚠️ **第 72 列越界安全告警（Overflow Linter）**：
  * 固定格式 COBOL 中，第 73 列以后的字符会被编译器彻底忽略。插件自动用红色波浪下划线标红超出 72 列的代码字符，防止隐蔽 Bug。
* 🚀 **过程段落与数据定义直达 (`gd` / `<C-o>`)**：
  * 光标停在 `PERFORM 1000-INITIALIZE` 上按 `gd` 直达第 83 行段落定义；
  * 光标停在变量名（如 `WS-FLAGS`、`INPUT-RECORD`、`EOF-YES`）上按 `gd` 直跳 `DATA DIVISION` 声明行；
  * 原生集成 Neovim Jumplist 与 Tagstack，按 `<C-o>`（或 `<C-t>`）无缝原路跳回！
* 📖 **Copybook 文件打开与悬停浮窗预览 (`gf` / `K`)**：
  * 光标在 `COPY "EMP-REC.CPY".` 上按 `gf`：在预设路径中自动检索并直接打开目标文件；
  * 在 `COPY` 行或过程段落名上按 `K`：居中弹出圆角浮动窗口（COBOL 语法高亮），就地预览内容，按 `q` 或 `<Esc>` 随手关闭，绝不打断思路。
* 🗺️ **Aerial 侧边栏层级大纲 (`<leader>cs`)**：
  * 3 层树状符号大纲：Divisions -> Sections -> Paragraphs / FDs / 01 级记录；
  * 支持回车跳转与双向光标跟随高亮。
* 💬 **第 7 列智能注释切换**：
  * `<leader>c*` / `:CobolToggleComment`：精准在第 7 列插入或移除 `*` 注释符，支持单行与 Visual 多行选区，绝不破坏原有代码缩进。
* ⚡ **智能 Tab 吸附与列跳转**：
  * 行首缩进时按 Tab：1-6 列自动跳至第 8 列（Area A），7-11 列自动跳至第 12 列（Area B）。
  * 快捷跳转：`g7`（Indicator）、`g8`（Area A）、`g12`（Area B）、`g73`（Identification）。
* 🔍 **数据层级宿主回溯 (Hierarchy Parent Hint)**：
  * 光标停留在深层嵌套字段（如 `10 IN-FULL-NAME`）时，行尾以淡灰斜体显示父级与顶层对象：`← 05 IN-NAME-GROUP (01 WS-INPUT-FIELDS)`。
* 🧮 **数据层级与 PIC 结构计算器 (Data & PIC Size Calculator)**：
  * 光标停留在变量行时，行尾以虚拟文本实时展示物理字节数（如 `/* 20 B */`，`/* 5 B COMP-3 */`）。
  * 自动识别 `DISPLAY`、`COMP` / `BINARY`（半字/全字/双字）、`COMP-3` / `PACKED-DECIMAL`（压缩十进制）、`OCCURS` 重复项与 `REDEFINES` 内存共享。
  * 光标位于 `01` 根记录时，自动递归向下汇总子字段字节总和，并在行尾提示 `/* Total: 398 Bytes (6 fields) */`。
  * 按 `<leader>cr` / `:CobolCalcRecord`：居中弹出精美 ASCII 表格，列出各字段层级、物理偏移量（Offset）、字节大小与存储类型。
* 🩺 **GnuCOBOL (`cobc`) 实时异步语法飞检与诊断 (Real-time Diagnostics)**：
  * 依托原生 `vim.system`，非阻塞异步调用 `cobc -fsyntax-only`。
  * 保存文件（`BufWritePost`）、内容修改防抖（`TextChanged`）或离开插入模式（`InsertLeave`）时自动飞检，零延迟、零卡顿。
  * 自动将编译器报错精准映射为 Neovim 原生 Diagnostics，在代码行下绘制红/黄色波浪下划线；精准定位出错标识符或段落名。
  * 联动 Copybook：当引用的外部 `.CPY` 发生语法错误时，不仅在主程序 `COPY` 语句处醒目提示 `[In EMP-REC.CPY:5] ...`，若该 Copybook 已在编辑区打开，同时精准同步标记到该 Copybook 对应行。
  * 快捷键 `<leader>cl` 立即触发飞检，`<leader>cq` 呼出 Quickfix 诊断列表。
* 🛡️ **智能屏蔽干扰**：
  * 自动在 COBOL 缓冲区静默通用语言缩进线（`indent-blankline.nvim`），避免多重线条互相冲突。

---

## 快捷键一览 (Keymaps)

| 快捷键 | 模式 | 适用对象 | 功能说明 |
|---|---|---|---|
| `<leader>uc` | Normal | 全局 | 一键开关整个 COBOL 细线标尺与 Winbar 刻度 |
| `<leader>cs` | Normal | 全局 | 呼出/隐藏 Aerial 符号大纲侧边栏 |
| `<leader>cr` | Normal | 01 记录 / 字段 | **计算 01 记录内存排布与字节总和**（居中弹窗展示偏移量表格） |
| `<leader>cl` | Normal | 全局 | **立即触发 GnuCOBOL 语法飞检**（Cobol Lint） |
| `<leader>cq` | Normal | 全局 | **打开诊断 Quickfix 列表**（查看当前所有语法错误与告警） |
| `gd` | Normal | 段落 / 变量 / Copybook | **直达定义**（跳到段落定义行、数据字段行或 Copybook 文件） |
| `<C-o>` | Normal | 全局 | **跳回原位置**（Neovim 原生 Jumplist 回退） |
| `gf` | Normal | `COPY` 语句 | **打开文件**（直接打开光标处的 Copybook 实体文件） |
| `K` | Normal | `COPY` / `PERFORM` / 变量 | **悬停预览**（居中弹窗就地预览 Copybook 内容或过程定义片段） |
| `g7` | Normal | 当前行 | 光标直跳第 7 列（Indicator 注释列） |
| `g8` | Normal | 当前行 | 光标直跳第 8 列（Area A 起始） |
| `g12` | Normal | 当前行 | 光标直跳第 12 列（Area B 起始） |
| `g73` | Normal | 当前行 | 光标直跳第 73 列（Identification 识别区起始） |
| `<leader>c*` | Normal / Visual | 当前行 / 多选选区 | 在第 7 列插入/移除 `*` 注释标记（支持选中多行） |
| `<Tab>` | Insert | 行首或前导空白 | 行首或前导空白处自动吸附到第 8 列或第 12 列 |
| `q` 或 `<Esc>` | Normal | 预览/计算浮窗内 | 随手关闭悬停预览或内存计算浮窗 |

---

## 用户命令 (Commands)

* `:CobolGotoDef` - 直达定义行（等价于 `gd`）
* `:CobolGotoCopybook` - 打开 Copybook 文件（等价于 `gf`）
* `:CobolPreview` - 弹窗预览光标处 Copybook 或过程定义（等价于 `K`）
* `:CobolCalcRecord` - 计算当前 01 记录内存排布与总字节数（等价于 `<leader>cr`）
* `:CobolLint` - 立即执行 GnuCOBOL 编译器语法飞检（等价于 `<leader>cl`）
* `:CobolQuickfix` - 打开语法诊断 Quickfix 列表（等价于 `<leader>cq`）
* `:CobolDiagnosticsToggle` - 开启/关闭语法飞检诊断
* `:CobolToggleComment` - 在第 7 列切换注释（等价于 `<leader>c*`）
* `:CobolGuideToggle` - 切换标尺与 Winbar（等价于 `<leader>uc`）
* `:CobolGuideEnable` - 开启标尺与 Winbar
* `:CobolGuideDisable` - 关闭标尺与 Winbar

---

## 路线图与功能验证 (Roadmap & Verification)

详细功能规划、实现规格与测试自检清单请参见 [docs/ROADMAP.md](docs/ROADMAP.md) 以及手册 [COBOL_NVIM_GUIDE.md](../../docs/COBOL_NVIM_GUIDE.md)：
* **Phase 1: 穿孔卡标尺与安全边界**（已完成 ✅）：纯细线标尺、Winbar 刻度、72 列溢出告警、第 7 列注释、快捷跳转与 Tab 吸附。
* **Phase 2.1: 结构大纲与层级展示**（已完成 ✅）：Winbar 段落面包屑、01/88 级高亮与行尾宿主回溯、Aerial 侧边栏 3 层符号树（`<leader>cs`）。
* **Phase 2.2: 代码定义跳转与 Copybook 预览**（已完成 ✅）：`PERFORM` / `GO TO` 段落一键直达（`gd` / `<C-o>`）、`COPY` Copybook 文件跳转（`gf`）与悬浮窗预览（`K`）。
* **Phase 3: 数据层级与 PIC 结构计算器**（已完成 ✅）：单项 `PIC` 字节换算、`01 RECORD` 自动递归汇总总字节数、ASCII 内存排布表（`<leader>cr`）。
* **Phase 4: 编译器实时语法飞检**（已完成 ✅）：GnuCOBOL (`cobc -fsyntax-only`) 异步语法飞检、Neovim Diagnostics 映射、标识符精确下划线、Copybook 穿透标记（`<leader>cl` / `<leader>cq`）。
* **Phase 5: 语法折叠与格式化**（优化计划 📌）：Division/Section/Paragraph 语法级折叠（`za`）、保留字大小写规范化。

---

## License

MIT
