# cobol.nvim 开发路线图与功能验证手册 (Roadmap & Verification Manual)

本文档记录 `cobol.nvim` 的架构演进、阶段规划与功能验证清单，供开发与日常使用时对照检查。

---

## 愿景与设计哲学

1. **尊重穿孔卡标准，消除隐蔽痛点**：严格契合 80 列穿孔卡固定格式（Fixed-Format 68/74/85），消灭缩进错位、72 列越界代码丢失等编译 Bug。
2. **零侵入，高质感终端视觉**：采用 Neovim 视口原生虚拟文本（Extmarks）与单字符纤细标尺（`│`），无遮挡、无性能损耗、坚决不用粗糙背景色块。
3. **赋予大型机代码现代 IDE 体验**：在无笨重外部 LSP 的情况下，通过纯原生 Lua 提供秒级大纲导航、段落直达、Copybook 浮窗预览、PIC 字节换算与实时语法飞检。

---

## 功能阶段演进与完成度总览

| 阶段 | 模块名称 | 核心功能 | 状态 | 验证入口 |
|---|---|---|---|---|
| **Phase 1** | **穿孔卡标尺与安全边界** | 7/8/12/73 纯细线标尺、Winbar 动态打孔卡刻度、72 列越界波浪红告警、第 7 列智能注释、智能 Tab 吸附、列跳转快捷键 | **已完成 (v0.1.0) ✅** | `<leader>uc`, `g7/g8/g12/g73`, `<leader>c*`, `Tab` |
| **Phase 2.1** | **大纲结构与层级展示** | Winbar 实时段落面包屑、DATA DIVISION 01/88 级着色、行尾结构回溯 (`← 05`)、Aerial 侧边栏 3 层符号树 (`<leader>cs`) | **已完成 (v0.2.0) ✅** | Winbar, `<leader>cs`, 行尾 Virtual Text |
| **Phase 2.2** | **代码定义跳转与 Copybook 预览** | `PERFORM`/`GO TO` 段落一键直达 (`gd` / `<C-o>`)、`COPY` Copybook 文件跳转 (`gf`)、`COPY` 行悬浮窗预览结构 (`K`) | **已完成 (v0.2.1) ✅** | `gd`, `<C-o>`, `gf`, `K` |
| **Phase 3** | **数据层级与 PIC 结构计算器** | 单项 PIC 字节换算（支持 `COMP`/`COMP-3`）、`01 RECORD` 自动递归汇总总字节数（Virtual Text / Command） | **进阶计划 📌** | 01 行行尾提示, `:CobolCalcRecord` |
| **Phase 4** | **编译器实时语法飞检** | GnuCOBOL (`cobc -fsyntax-only`) 异步语法飞检、Neovim Diagnostics 映射（标点/列错位/未定义报错） | **安全计划 📌** | 保存/停顿触发 Diagnostics 诊断 |
| **Phase 5** | **语法折叠与格式化** | Division / Section / Paragraph 语法级折叠 (`za`)、COBOL 保留字大小写规范化 (`:CobolFormatCase`) | **优化计划 📌** | `za`, `:CobolFormatCase` |

---

## 阶段功能详细规格与自检清单

### Phase 1: 穿孔卡标尺与安全边界（已完成 ✅）

* [x] **纯细线标尺（`show_lines`）**
  - **位置**：第 7 列（Indicator）、8 列（Area A）、12 列（Area B）、73 列（Past Area B）。
  - **样式**：纤细字符 `│`，前景色为低对比淡钢蓝（`#3b638c`），零背景色。
  - **行为**：代码文字处自动避让不遮挡；空行短行贯穿屏幕。
* [x] **Winbar 动态打孔卡刻度（`show_winbar`）**
  - **样式**：`..SEQ.*A...B..........................................72IDENT...`。
  - **动态对齐**：根据窗口行号/符号列宽度（`textoff`）动态填充前导空格，保证刻度字符与下方代码列 100% 垂直对应。
* [x] **第 72 列越界安全告警（`highlight_overflow`）**
  - **行为**：代码超出第 72 列部分采用醒目波浪下划线标红（`CobolColumnOverflow`），防止代码掉入第 73-80 列 Identification 区被编译器忽略。
* [x] **第 7 列智能注释切换（`smart_comments`）**
  - **按键**：`<leader>c*` / 命令 `:CobolToggleComment`。
  - **行为**：精准在第 7 列放置或移除 `*`，支持单行与 Visual 模式多选，绝不破坏原有代码缩进。
* [x] **智能 Tab 吸附与快捷列跳转**
  - **Tab 吸附**：行首/空白处按 `<Tab>`：1-6 列直跳第 8 列（Area A），7-11 列直跳第 12 列（Area B）。
  - **列跳转**：`g7`（跳 Col 7）、`g8`（跳 Col 8）、`g12`（跳 Col 12）、`g73`（跳 Col 73）。
* [x] **缩进线干扰屏蔽**
  - 进入 COBOL buffer 自动静默 `indent-blankline.nvim`，消除多重竖线重叠混淆。

---

### Phase 2.1: 结构大纲与层级展示（已完成 ✅）

* [x] **Winbar 实时段落面包屑（`show_breadcrumbs`）**
  - **显示**：在 Winbar 标尺右侧动态显示当前光标所属架构，如 `[ PROCEDURE > 2000-PROCESS > 2100-PROCESS-RECORD ]` 或 `[ DATA > WORKING-STORAGE > 01 WS-INPUT-FIELDS > IN-FULL-NAME ]`。
* [x] **DATA DIVISION 01 / 88 级高亮与宿主回溯**
  - `01` 顶级记录以亮蓝高亮；`88` 级条件名以鲜明紫/金黄高亮。
  - 光标移动至嵌套字段时，行尾以淡灰斜体显示其父级结构：`  ← 05 IN-NAME-GROUP (01 WS-INPUT-FIELDS)`。
* [x] **Aerial 侧边栏层级大纲（`<leader>cs`）**
  - 4 大 DIVISION（`Module` 级图标）作为顶层根节点。
  - 各类 SECTION（`Interface` 级）作为中层节点。
  - 过程段落（`Function` 级）和 FD / 01 级记录（`Struct` 级）作为底层叶子节点。
  - 支持双击/回车精准跳至对应行列，光标移动时光标所在段落高亮跟随。

---

### Phase 2.2: 代码定义跳转与 Copybook 预览（已完成 ✅）

#### 1. `PERFORM` / `GO TO` 段落一键直达 (`gd`)
* **痛点**：没有安装大型 COBOL LSP 时，光标停在 `PERFORM 2000-PROCESS-FILE` 上按 `gd` 会提示找不到定义，只能手动 `/` 搜索。
* **技术方案**：
  - 光标位于某词上时，解析光标当前单词。
  - 向上或全局正则搜索 `^\s*<WORD>\.\s*$`（顶格在 Area A 且以点结尾的段落/节定义），并支持跳至 `DATA DIVISION` 的字段与 `01/05/88/FD`。
  - 压入 Neovim 标签栈（`tagstack` 与 `jumplist`），跳转后可直接使用 `<C-o>` 原路跳回。
* **自检项**：
  - [x] 光标在 `PERFORM 1000-INITIALIZE` 上按 `gd`，能否直跳第 83 行 `1000-INITIALIZE.`。
  - [x] 跳转后按 `<C-o>`，能否精确返回之前的 `PERFORM` 行。
  - [x] 若光标所在词不是合法段落名，给出友好的浮窗/状态栏提示。

#### 2. `COPY` Copybook 文件跳转 (`gf`)
* **痛点**：COBOL 项目由大量 `.CPY` / `.cbl` 组合而成（如 `COPY "EMP-REC.CPY".`），手工打开极其繁琐。
* **技术方案**：
  - 拦截/增强 COBOL buffer 的 `gf` 快捷键。
  - 正则捕获行内的 `COPY\s+["']?([%w%-%.]+)["']?`。
  - 配置搜索路径：`copybook_paths = { ".", "./cpy", "./include", "../copybooks", "../include" }`。
  - 找到文件后在当前窗口或以 split 打开。
* **自检项**：
  - [x] 光标停在 `COPY "EMP-REC.CPY".` 行，按 `gf` 能否直接打开 `/home/tetsuya/development/cobol/EMP-REC.CPY`。

#### 3. `COPY` 悬浮窗快速预览 (`K` / Hover)
* **痛点**：很多时候只是想确认 Copybook 里某个变量的名字和类型，不希望破坏当前的窗口布局去打开一个新 tab 或 split。
* **技术方案**：
  - 当光标位于带有 `COPY` 的行并按下 `K`（Normal 模式悬停快捷键）时，读取目标 Copybook 文件内容。
  - 弹出一个带有边框的居中浮动窗口（Floating Window），以 COBOL 语法高亮展示前 30 行（支持滚动）。
  - 按 `q`、`<Esc>` 或光标移走时自动关闭浮窗。
* **自检项**：
  - [x] 光标停在 `COPY "EMP-REC.CPY".` 上按 `K`，是否弹窗显示 `EMP-RECORD` 结构。
  - [x] 按 `q` 或 `<Esc>` 是否平滑关闭。

---

### Phase 3: 数据层级与 PIC 结构计算器（进阶实施 📌）

#### 1. 单项 PIC 字节换算（Virtual Text / Hover）
* **换算规则**：
  - `PIC X(20)` / `PIC A(10)`：字符型，直接计为 `20` 字节 / `10` 字节。
  - `PIC 9(5)V99`：数值型，共 7 位数字，无 COMP 时字符形式占 `7` 字节。
  - `PIC S9(7) COMP-3`：Packed-Decimal（压缩十进制），公式为 `floor((N + 1) / 2)`，7 位占 `4` 字节。
  - `PIC S9(4) COMP` / `BINARY`：二进制半字（1-4 位占 2 字节，5-9 位占 4 字节，10-18 位占 8 字节）。
* **自检项**：
  - [ ] 光标停留在数据行时，能否正确换算并展示单项占用的字节大小。

#### 2. `01 RECORD` 自动递归汇总总字节数
* **痛点**：设计数据文件或报文接口时，必须算出整个 01 结构体的精确字节总和（用于确认是否与文件定长 256 字节匹配）。
* **技术方案**：
  - 当光标停留在 `01  INPUT-RECORD` 时，自动向下遍历直到下一个同级（`01`/`77`/`FD`/`SECTION`）。
  - 收集所有基本字段（非包含组字段），累加字节数。
  - 在 `01` 行行尾以 Virtual Text 形式提示：`/* Record Size: 256 Bytes */`；或提供命令 `:CobolCalcRecord` 输出明细报表。
* **自检项**：
  - [ ] 对测试 demo `INPUTCSV.COB` 中的 `01 WS-INPUT-FIELDS` 运行，是否准确计算其所有成员的字节和。

---

### Phase 4: 编译器实时语法飞检（安全实施 📌）

#### 1. GnuCOBOL (`cobc`) 异步 Diagnostics
* **技术方案**：
  - 利用系统已安装的 `cobc`：`cobc -fsyntax-only -std=cobol85 -I <copybook_dir> <temp_file>`。
  - 在 `BufWritePost`（保存时）或带有防抖的 `CursorHold` 时异步在后台运行，不阻塞 Neovim 编辑。
  - 抓取输出如：`file.cob:89: error: syntax error, unexpected ...`。
  - 转化为 Neovim 原生 `vim.diagnostic.set`，直接在代码行上绘制红色/黄色波浪线。
* **常见捕获问题**：
  - 漏掉句号 `.`
  - 关键字在 Area A 与 Area B 错位
  - 使用未定义的段落或变量
  - 块未闭合（如缺少 `END-IF`、`END-PERFORM`）
* **自检项**：
  - [ ] 故意删掉某行末尾的 `.` 并保存，对应行是否立即出现红色错误波浪线并在浮窗提示。
  - [ ] 补上 `.` 后保存，错误是否立即消除。

---

### Phase 5: 语法折叠与保留字格式化（优化实施 📌）

* [ ] **COBOL 语法折叠（`foldexpr`）**：
  - 依据已成熟的 Division / Section / Paragraph 行号范围分析，为 COBOL 设置折叠方法。
  - 在 `DATA DIVISION` 处按 `zc` 可折叠整个庞大数据区；在某个段落处按 `zc` 可收起段落内部代码。
* [ ] **保留字规范化命令（`:CobolFormatCase`）**：
  - 提供单命令将选区或全篇文件的 COBOL 关键字（如 `move`, `perform`, `display`, `if`, `end-if`）格式化为全大写，保留变量与字面量不变。

---

## 验证与检查操作指南

每次实现或修改完功能后，按以下步骤对照检查：
1. **测试用例文件**：打开真实测试代码 `/home/tetsuya/development/cobol/INPUTCSV.COB` 与 `EMP-REC.CPY`。
2. **测试快捷键**：
   - 基础标尺：`<leader>uc` 开关、`g7`/`g8`/`g12`/`g73` 穿梭、`Tab` 缩进吸附。
   - 大纲符号：`<leader>cs` 检查 Aerial 树状图与跳转。
   - 导航与跳转：`gd` 检查段落跳转与 `<C-o>` 回退、`gf` 与 `K` 检查 Copybook 跳转与浮窗。
   - 字节计算：检查 01 行行尾总大小计算是否符合预期。
   - 语法诊断：模拟缺少标点保存看波浪线。
3. **工作区状态与提交**：
   - 子仓库提交：`cd ~/chezmoi/dot_config/nvim-private/lua/cobol.nvim && git commit -m "..." && git push`
   - 主配置同步：`cd ~/chezmoi && git add dot_config/nvim-private/lua/cobol.nvim && git commit -m "..." && chezmoi apply`
