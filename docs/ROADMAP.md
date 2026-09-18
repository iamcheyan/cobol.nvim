# cobol.nvim 开发路线图（Roadmap & Design Specs）

本文档记录 `cobol.nvim` 的架构愿景、功能规划与逐步落地的开发路线图。

---

## 愿景与设计哲学

在现代编辑器（Neovim）中重构最古老但最核心的商业语言（COBOL）的开发体验：
1. **尊重标准，消除痛点**：严格契合 80 列穿孔卡固定格式（Fixed-Format 68/74/85），解决对齐难、越界隐蔽 Bug 等核心问题。
2. **零侵入，高质感**：使用终端原生虚拟文本（Extmarks）与纤细字符标尺（`│`），坚决不用笨重的整列背景色块。
3. **现代化工作流**：为庞大冗长的大型机代码赋予类似现代语言的快速跳转、面包屑大纲、结构计算与即时语法检测。

---

## 功能阶段演进表

| 阶段 | 模块名称 | 核心功能 | 状态 |
|---|---|---|---|
| **Phase 1** | **标尺与安全边界** | 虚拟细线标尺 (7/8/12/73)、Winbar 打孔卡刻度、第 72 列越界告警、智能第 7 列注释、缩进干扰屏蔽 | **已完成 (v0.1.0)** |
| **Phase 2** | **结构大纲与快速导航** | Winbar 右侧段落面包屑、`PERFORM`/`CALL` 段落一键直达 (`gd`)、`COPY` Copybook 跳转 (`gf`) | **进行中 (v0.2.0)** |
| **Phase 3** | **数据层级与 PIC 计算器** | `DATA DIVISION` 01-88 级高亮、88 级宿主回溯、`PIC` 字段长度与 Record 总字节数自动求和、`COMP-3` 字节换算 | **规划中 (v0.3.0)** |
| **Phase 4** | **工程化与编译器诊断** | GnuCOBOL (`cobc`) 实时语法飞检 (Linting)、保留字大小写规范化、分屏 Copybook 浮窗预览 | **规划中 (v0.4.0)** |

---

## 阶段细节与技术实现规范

### Phase 1: 标尺视觉与安全边界（已完成 ✅）

* [x] **纯细线标尺（`show_lines`）**：
  * 使用 `decoration_provider` + `virt_text_win_col` 在第 7、8、12、73 列绘制 `│`。
  * 遇到代码文字时自动避让不遮挡；遇到空白处和空行时贯穿整屏。
  * 背景色全透明（`bg = "NONE"`），前景色为淡钢蓝（`#3b638c`）。
* [x] **Winbar 动态打孔卡标尺（`show_winbar`）**：
  * 通过 `vim.fn.getwininfo(win_id)[1].textoff` 动态探测行号/折叠宽度，补齐左侧空格，使刻度字符与下方代码列 100% 垂直对应。
* [x] **第 72 列越界安全告警（`highlight_overflow`）**：
  * 使用正则匹配第 72 屏列之后的非注释代码，采用波浪下划线醒目标红，防止写出的代码掉入 Identification 区被编译器无情忽略。
* [x] **第 7 列智能注释切换（`smart_comments`）**：
  * 专为固定格式设计的 `<leader>c*` / `:CobolToggleComment`，支持单行与 Visual 多行，绝不破坏原有代码缩进。
* [x] **智能 Tab（`smart_tab`）**：
  * 行首或前导空白处按 Tab：1-6 列直跳 Area A（第 8 列），7-11 列直跳 Area B（第 12 列）。
* [x] **隔离通用缩进线干扰**：
  * 自动在 COBOL 缓冲区静默 `indent-blankline.nvim`，消除多重线条重合冲突。

---

### Phase 2: 结构大纲与快速导航（开发计划 📌）

#### 1. Winbar 实时段落面包屑（Breadcrumbs）
* **目标**：在长达几千行的 COBOL 文件中，顶部随时获知当前光标所属的执行块。
* **视觉形式**：
  ```text
  ..SEQ.*A...B..........................................72  [PROCEDURE > 2000-PROCESS-DATA]
  ```
* **实现原理**：
  * 向上快速回溯查找最近的 `DIVISION`、`SECTION` 与 `PARAGRAPH.`（以 `.` 结尾且顶格在 Area A 的非保留行）。
  * 结合 Treesitter 或纯 Lua 正则解析器，缓存行号范围，确保每次光标移动延迟小于 1ms。

#### 2. `PERFORM` / `GO TO` 段落一键直达（轻量 `gd` 跳转）
* **目标**：在没有大型 COBOL LSP 的环境下，按下 `gd` 能精准跳转到目标段落定义处。
* **实现原理**：
  * 获取当前光标下的词（如 `2000-PROCESS-DATA`）。
  * 优先在当前 buffer 查找符合 `^\s*<WORD>\.\s*$` 的行定义。
  * 将当前跳转推入 Neovim 标签栈（Tag Stack），支持按 `<C-o>` 无缝跳回。

#### 3. `COPY` Copybook 一键跳入（`gf` 扩展）
* **目标**：在 `COPY "CUSTREC.CPY"` 或 `COPY CUSTREC.` 语句上按 `gf`，自动在分屏或悬浮窗中打开对应的 Copybook 文件。
* **配置项**：
  ```lua
  copybook_paths = { ".", "./cpy", "./include", "../copybooks" }
  copybook_extensions = { ".cpy", ".CPY", ".cbl", ".CBL" }
  ```

---

### Phase 3: 数据层级与 PIC 结构计算器（开发计划 📌）

#### 1. 数据层级（01 / 05 / 10 / 88）高亮与结构指引
* **`88` 级（条件名/枚举值）**：赋予特殊的醒目颜色（如亮紫色），与常规数据项明确区分。
* **宿主回溯浮窗**：当光标停留在嵌套深度的变量（如 `10 FIRST-NAME`）时，浮窗或虚拟文本提示其父级结构：`Parent: 05 CUSTOMER-NAME (01 CUSTOMER-RECORD)`。

#### 2. PIC 长度与 Record 总字节数自动求和（核心效率神器）
* **PIC 单项长度换算**：
  * `PIC X(20)` → 20 bytes
  * `PIC 9(5)V99` → 7 digits (5 integer + 2 decimal)
  * `PIC S9(7) COMP-3` → 压缩十进制：`(7 + 1) / 2 = 4 bytes`
  * `PIC S9(4) COMP` → 二进制半字：`2 bytes`
  * `PIC S9(9) COMP` → 二进制全字：`4 bytes`
* **01 Record 自动总计**：
  * 光标位于 `01  RECORD-NAME.` 行时，自动向下扫描所属的所有子字段，计算整个 Record 的总字节数并提示：
    ```text
    01  INPUT-RECORD.                 /* Record Size: 256 bytes */
    ```

---

### Phase 4: 现代工程化与编译器集成（开发计划 📌）

#### 1. GnuCOBOL (`cobc`) 实时语法飞检（On-the-Fly Diagnostics）
* 集成 `cobc -fsyntax-only -std=cobol85`：
* 在保存或空闲停顿（`CursorHold`）时异步执行，将编译器报错精准映射为 Neovim Diagnostics：
  * 缺失末尾句号 `.`
  * 跨列非法（Area A 关键字写在 Area B，或相反）
  * 变量未定义或未闭合块

#### 2. 保留字大小写格式化（Case Normalizer）
* 提供一键命令 `:CobolFormatCase`：
* 将 COBOL 85 核心保留字（如 `move`, `perform`, `division`, `pic`, `stop run` 等）自动格式化为全大写，保持变量名原样或统一规则。
