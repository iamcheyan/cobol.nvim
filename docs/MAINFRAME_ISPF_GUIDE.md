# IBM z/OS 大型机 ISPF 编辑器与 cobol.nvim 现代化融合指南

本文档深入解析经典 IBM z/OS ISPF/PDF 编辑器的核心机制与设计思想，并记录 `cobol.nvim` 吸收大型机精髓、进行现代化转化的架构设计与使用指南。

---

## 1. 经典 IBM z/OS ISPF Edit 界面深度解析

在 3270 终端（绿屏/彩色屏）上，IBM z/OS 的 ISPF (Interactive System Productivity Facility) 是数十年大型机开发的事实标准。截图中展现的是典型的 `ISPF Edit - COBOL` 编程界面：

```text
  File  Edit  Edit_Settings  Menu  Utilities  Compilers  Test  Help
-------------------------------------------------------------------------------
EDIT       IBMUSER.COBLOG4.COBOL(TEST) - 01.01                 Columns 00001 00072
=COLS> ----+----1----+----2----+----3----+----4----+----5----+----6----+----7--
****** ***************************** Top of Data ******************************
==MSG> -Warning- The UNDO command is not available until you change
==MSG>           your edit profile using the command RECOVERY ON.
000001    IDENTIFICATION DIVISION.
000002    PROGRAM-ID. TEST.
000003    PROCEDURE DIVISION.
000004        DISPLAY "Z/OS SAYS HELLO WORLD!".
000005        STOP RUN.
****** **************************** Bottom of Data *****************************
Command ===>                                                Scroll ===> PAGE
```

### 各区域及技术含义剖析

1. **顶部操作栏 (Action Bar)**
   - `File Edit Edit_Settings Menu Utilities Compilers Test Help`
   - 通过终端功能键（如 F10）激活，可快速调用编译批处理、SDSF 作业查看、PDS 数据集工具等。

2. **状态与标题行 (Header & Title Line)**
   - `EDIT`：表示当前处于可写编辑模式（对应只读的 `VIEW` 或 `BROWSE` 模式）。
   - `IBMUSER.COBLOG4.COBOL(TEST)`：大型机数据集定位：
     - `IBMUSER.COBLOG4.COBOL`：PDS/PDSE（分区数据集，类似目录）。
     - `(TEST)`：Member 成员名（具体文件）。
   - `- 01.01`：ISPF Statistics 统计版本号（Version 01, Modification 01）。
   - `Columns 00001 00072`：屏幕横向可视列范围（第 1 列至第 72 列）。COBOL 固定格式的有效代码列严格位于 1–72 列内，73–80 为识别/流水号区。

3. **标尺刻度行 (COLS Line / Column Indicator)**
   - `=COLS> ----+----1----+----2----+----3----+----4----+----5----+----6----+----7--`
   - 大型机编写固定格式代码的“生命线”：
     - 每 5 格一个 `+`，每 10 格一个数字 `1, 2, ..., 7`。
     - **第 7 列**：指示符区（Indicator Area，`*` 为注释，`-` 为续行，`/` 为换页，`D` 为调试）。
     - **第 8 列**：Area A 开始（`----+----1` 中的第 8 格，用于声明 Division、Section、Paragraph、01/77 级记录）。
     - **第 12 列**：Area B 开始（`1` 后第 2 格，用于具体指令语句、子级别数据定义）。
     - **第 72 列**：有效代码终点。

4. **数据边界提示 (Top / Bottom of Data)**
   - `****** Top of Data ******` 与 `****** Bottom of Data ******`
   - 终端按页切换时，明确指示数据物理边界。

5. **系统消息行 (Informational / Message Line, ==MSG>)**
   - 编辑器向用户展示 profile 告警（如 `RECOVERY ON` / `UNDO` 状态），存盘时不会写入源码文件。

6. **前缀行号与行命令区 (Line Command Area)**
   - 绿色的 6 位数字 `000001` - `000005`。
   - **交互核心**：用户直接在此区域键入命令（如 `i` 插入行，`dd` 删行，`cc` 复制，`cols` 显隐标尺，`x` 折叠行等）。

7. **底端主命令行与滚动量 (Primary Command Line & Scroll Field)**
   - `Command ===>`：输入全局命令（如 `FIND`、`HEX ON`、`SUBMIT` 等）。
   - `Scroll ===> PAGE`：翻页滚动步长（PAGE 整页、HALF 半页、CSR 滚到光标处）。

---

## 2. 现代 Neovim 的转化准则：保持编辑区源码纯粹

在现代 Neovim 编辑体验中，**核心原则是绝不在正文编辑区（文档内部）插入伪造内容或虚拟装饰行**。
如果像 3270 终端一样在源码区域注入 `=COLS>` 或 `Top of Data` 等虚拟行，极易产生视觉混乱，导致开发者分不清哪些是文档本身的真实代码，哪些是插件插入的虚拟装饰，破坏编码心流。

因此，`cobol.nvim` 采用精准、无侵入的现代化设计：
1. **纯净轻量的竖线引导**：只保留编辑区 7/8/12/73 列的无背景字符细线（`│`），零文本污染。
2. **独立浮窗工具**：十六进制 / EBCDIC / COMP-3 视图使用独立浮窗（Float Window），随用随开，按 `q` 随手关闭。
3. **精准序列号命令**：提供针对 1-6 列行号的 `:CobolRenum` 和 `:CobolUnnum`，安全受控。
4. **透明输入流大写转换**：提供 `:CobolCapsToggle` 智能大写输入，无需 CapsLock，保持字面量和注释大小写。

---

## 3. 已集成的 ISPF 现代化特性与使用手册

### ① 行序号智能管理（`:CobolRenum` / `:CobolUnnum`）

大型机 PDS 数据集通常要求第 1–6 列携带 6 位递增序号（如 `000100`），第 73–80 列携带 Program ID。而现代 Git 协作通常需要清空这些序号以避免产生海量冲突 diff。

- **`:CobolRenum [start] [step] [label]`**
  - 为指定范围（或当前全文件）的第 1–6 列生成 6 位自增行号，同时严格保护第 7 列指示符不受影响。
  - 支持第 3 个参数在第 73–80 列填入指定的 8 位成员标识符。
  - **示例**：
    - `:CobolRenum`：从 100 开始，按步长 100 递增（`000100`, `000200`, `000300`...）
    - `:CobolRenum 10 10`：从 10 开始，步长 10（`000010`, `000020`...）
    - `:CobolRenum 100 100 TESTPROG`：生成序号并在 73–80 列填充 `TESTPROG`
    - 可视模式：选中多行后执行 `:'<,'>CobolRenum 500 100`，只重新编号选中区域。

- **`:CobolUnnum [all|seq]`**
  - 清空第 1–6 列的序号（全部替换为标准 6 个空格），并保留第 7 列指示符及之后的代码。
  - 默认同时清除第 73–80 列的识别区文本，使文件完全符合现代 Git 纯净代码标准。
  - **示例**：
    - `:CobolUnnum`：清空 1–6 列与 73–80 列
    - `:CobolUnnum seq`：仅清空 1–6 列，保留 73 列之后的标识

---

### ② 十六进制、EBCDIC 与 COMP-3 检查窗（`:CobolHex`）

还原 ISPF 经典的 `HEX ON` 核心能力，解决大型机二进制与紧凑十进制无法直观阅读的痛点。

- **功能亮点**：
  1. **EBCDIC 转换 (IBM Code Page 037 / CP1047)**：将当前字符/字符串转换为大型机原生 EBCDIC 字节序列。
  2. **ISPF 垂直 Nibble 视图**：
     - 第一行：字符展示
     - 第二行：高 4 位十六进制 Nibble
     - 第三行：低 4 位十六进制 Nibble
  3. **COMP-3 (Packed Decimal) 智能解码**：
     - 自动检测并解码紧凑十进制数值（包含正数符号位 `C/A/E`，负数符号位 `D/B`，无符号位 `F`）。
     - 例如检查 `01234C` 会直接解析为 `+1234`，检查 `0567D` 会解析为 `-567`。
- **命令与快捷键**：
  - `:CobolHex`：检查光标下的当前单词（或整行）
  - `:CobolHex <string>`：检查指定的十六进制或文本
  - 可视模式：选中文本后执行 `:'<,'>CobolHex`
  - 默认快捷键：`<leader>ch`（普通模式与可视模式均生效）
  - 检查窗口内按 `q` 或 `<Esc>` 即可关闭。

---

### ③ 智能大写输入模式（Smart CAPS）

- **工作机制**：
  模拟 ISPF Edit 的 `CAPS ON` 工作方式。在 Insert 模式下输入小写英文字母时自动转为大写，无需手动开启键盘的大写锁定键。
- **智能规避保护**：
  - **第 7 列为 `*` 或 `/`（注释行）**：保留原始小写输入，方便撰写说明文档。
  - **处于双引号 `""` 或单引号 `''` 内部（字符串字面量）**：保留原始大小写，确保字面量数据精度。
- **命令与快捷键**：
  - `:CobolCapsToggle`：切换 Smart CAPS 模式（状态栏通知 `CAPS ON` / `CAPS OFF`）
  - 默认快捷键：`<leader>cc`

---

## 4. 推荐配置选项 (setup opts)

在您的 `init.lua` 或 lazy.nvim 配置中，可根据喜好自定义：

```lua
require("cobol").setup({
  -- 智能大写模式
  caps_mode = false,       -- 启动时是否默认开启 Smart CAPS（可通过 :CobolCapsToggle 或 <leader>cc 随时切换）

  -- 其余常规配置保持不变
  show_lines = true,       -- 编辑区内的 7/8/12/73 列细线竖线 (│)
  show_winbar = true,      -- 顶部 Winbar 面包屑与结构闭合提示
  show_breadcrumbs = true,
  keymaps = true,
})
```
