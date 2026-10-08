# cobol.nvim：COBOL 学习与 Neovim 实战手册

这是本插件的中文主手册，面向正在学习 COBOL、尤其是 GnuCOBOL 固定格式的开发者。内容按“先看懂源码、再写程序、然后检查和运行”的顺序介绍语言基础、插件功能、快捷键和练习。

`cobol.nvim` 为 COBOL 文件提供源码列标尺、固定格式缩进、结构导航、Copybook 搜索、PIC 布局估算、补全、折叠和编译器诊断。它不要求安装 COBOL LSP。Neovim 原生帮助页可用 `:help cobol.nvim` 打开；日常学习以本文为主。

[English](README.md) · [日本語](README.ja.md)

## 目录

1. [安装和第一次运行](#安装和第一次运行)
2. [COBOL 源码格式速查](#cobol-源码格式速查)
3. [插件快捷键与命令](#插件快捷键与命令)
4. [逐项学习插件功能](#逐项学习插件功能)
5. [GnuCOBOL 项目配置](#gnucobol-项目配置)
6. [COBOL 入门练习](#cobol-入门练习)
7. [PIC 与记录长度估算](#pic-与记录长度估算)
8. [常见问题](#常见问题)

## 安装和第一次运行

使用 lazy.nvim：

~~~lua
{
  "iamcheyan/cobol.nvim",
  ft = { "cobol", "cbl", "cob" },
  opts = {},
}
~~~

建议安装 GnuCOBOL，这样编译检查、构建和单文件运行才能使用。插件不会替你安装系统软件。`blink.cmp` 和 Aerial 都是可选插件：前者提供补全菜单，后者显示结构大纲。其余核心功能不依赖这两个插件。

打开 `.cbl`、`.cob`、`.cobol` 或 `.cpy` 文件后，先确认：

~~~vim
:set filetype?
~~~

结果应为 `cobol`、`cbl` 或 `cob`。插件会在这些 filetype 的缓冲区自动启用。用 `:CobolGuideToggle` 可以临时关闭或重新打开列标尺。

建议第一次按这个顺序试用：

1. 打开 COBOL 源码，找到列标尺并看清第 7、8、12、73 列。
2. 光标放在段落名或字段名上按 `gd`，然后按 `<C-o>` 返回。
3. 在 `COPY` 语句上按 `gf` 打开 Copybook，按 `K` 预览。
4. 光标放到一个 01 记录上，运行 `:CobolCalcRecord`。
5. 故意写一个小语法错误，运行 `:CobolLint`，再用 Quickfix 找错误。
6. 用 `za` 折叠当前结构，用 `:CobolBuild` 或 `:CobolRun` 完成编译循环。

## COBOL 源码格式速查

### 固定格式的列

固定格式沿用打孔卡布局。列号从 1 开始：

| 列 | 含义 | 写代码时注意 |
| --- | --- | --- |
| 1–6 | 序号区 | 通常为空；已有序号时插件的定列缩进不会改它 |
| 7 | 指示区 | 空格表示普通行；`*` 表示注释；`/` 表示换页；`-` 常用于续行 |
| 8–11 | Area A | 常放 Division、Section、Paragraph、01/77 等较高层定义 |
| 12–72 | Area B | 常放字段、语句、子句和过程代码 |
| 73–80 | 标识区 | 编译器通常不把这里当作程序正文；正文不要越过第 72 列 |

例如，下面每行开头的七个空格表示源码从第 8 列开始：

~~~cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HELLO.
       PROCEDURE DIVISION.
           DISPLAY "HELLO, COBOL".
           STOP RUN.
~~~

第 7 列注释行示例（六个空格后是星号）：

~~~cobol
      * 这是固定格式注释。
~~~

如果一行正文越过第 72 列，插件会高亮越界部分。标尺负责可视提示，不会自动改写源码。

### 固定格式与自由格式

固定格式必须遵守列位置。自由格式不使用这些固定列区。`source_format` 可以是：

- `fixed`：明确按固定格式处理，适合固定格式项目。
- `free`：自由格式；不应用固定列 Tab 停靠。
- `auto`：根据缓冲区内容判断；不确定时按固定格式处理。

插件重点服务固定格式编辑。格式判断错误时，在项目的 `.cobol.json` 中明确设置 `source_format`，不要只依赖自动判断。

### COBOL 程序的大致结构

- `IDENTIFICATION DIVISION`：程序身份信息，例如 `PROGRAM-ID`。
- `ENVIRONMENT DIVISION`：文件、设备和运行环境描述。
- `DATA DIVISION`：文件记录、工作区变量和链接区数据。
- `PROCEDURE DIVISION`：程序执行步骤。
- `SECTION`：一组相关的段落或声明。
- `Paragraph`：可由 `PERFORM` 调用的一段过程代码，通常以名称和句点开始。

最简单的可执行程序：

~~~cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HELLO.
       PROCEDURE DIVISION.
           DISPLAY "HELLO, COBOL".
           STOP RUN.
~~~

固定格式里，Division 和 Paragraph 名称通常放在 Area A，具体语句放在 Area B。句点有实际语法意义；不要为了缩进随意删掉它。

## 插件快捷键与命令

`<leader>` 取决于 Neovim 配置；常见设置是空格。以下映射默认只在 COBOL 缓冲区生效。运行 `:verbose nmap gd` 查询映射来源，用 `:map <按键>` 检查冲突。

| 快捷键 | 作用 |
| --- | --- |
| `g7`、`g8`、`g12`、`g73` | 跳到指示区、Area A、Area B、标识区 |
| `gd` | 跳到段落、Section 或数据定义；递归搜索引用的 Copybook；多结果时弹出选择 |
| `gf` | 在 `COPY` 语句上打开对应 Copybook；同名候选不唯一时弹出选择 |
| `K` | 预览光标所在定义或 Copybook |
| `<C-o>`、`<C-i>` | 返回上一个跳转位置、向前重走跳转记录 |
| `<leader>uc` | 切换列标尺 |
| `<leader>c*` | 切换当前行或 Visual 选区注释 |
| `gcc` | 切换当前行注释；可带 Vim 数量，如 `3gcc` |
| Visual `gc` | 切换所选行注释 |
| Insert `<Tab>`、`<S-Tab>` | 固定格式列停靠和反向停靠 |
| `<leader>cr` | 打开当前 01 记录的布局估算 |
| `<leader>cl` | 立即运行 GnuCOBOL 语法检查 |
| `<leader>cq` | 打开 COBOL 诊断 Quickfix 列表 |

### 所有插件命令

| 命令 | 用途 |
| --- | --- |
| `:CobolGuideToggle` | 开关列标尺和 Winbar 提示 |
| `:CobolGuideEnable` / `:CobolGuideDisable` | 强制开启或关闭列标尺 |
| `:CobolToggleComment` | 按当前格式切换注释；也接受行范围 |
| `:CobolGotoDef` | 执行 `gd` 定义跳转 |
| `:CobolGotoCopybook` | 执行 `gf` Copybook 跳转 |
| `:CobolPreview` | 执行 `K` 预览 |
| `:CobolCalcRecord` | 显示当前 01 记录的字段和偏移量 |
| `:CobolFormatCase` | 将范围内识别出的 COBOL 保留字改为大写 |
| `:CobolLint` | 立即运行 GnuCOBOL 语法检查 |
| `:CobolQuickfix` | 打开 COBOL 诊断 Quickfix 列表 |
| `:CobolDiagnosticsToggle` | 开关自动编译器诊断 |
| `:CobolBuild` | 构建当前源文件或调用项目构建命令 |
| `:CobolRun` | 构建并运行单文件程序，或调用项目运行命令 |
| `:CobolTest` | 调用项目测试命令；没有测试目标时执行语法检查 |

## 逐项学习插件功能

### 1. 列标尺、跳列与越界提示

第 7、8、12、73 列的细线标尺与 Winbar 刻度会随 COBOL 窗口显示。光标移动时，Winbar 还可显示当前 Division、Section、Paragraph 或 DATA 项上下文。标尺使用透明背景，不会盖住主题和光标行颜色。

练习：光标停在任意 COBOL 行，依次按 `g7`、`g8`、`g12`、`g73`，观察列位置。把光标移到第 73 列之后的正文，确认越界内容被突出显示。用 `<leader>uc` 暂时关闭，再按一次恢复。

### 2. 固定格式 Tab 和智能缩进

光标前只有空白时，Insert 模式的 `<Tab>` 会帮助你靠齐列位：

| 插入位置 | `<Tab>` |
| --- | --- |
| 第 1–6 列 | 移到第 7 列 |
| 第 7 列 | 移到第 8 列 |
| 第 8–11 列 | 移到第 12 列 |
| 第 12 列及之后 | 插入一个 `shiftwidth` 缩进；未设置或为 0 时按 4 个空格 |

`<S-Tab>` 反向经过这些列位；第 12 列之后按一个缩进宽度退回，但不越过第 12 列。插入点前已有代码时会交回普通编辑器行为，不删除右侧源码。自由格式 COBOL 不使用固定格式列停靠。

缩进表达式会识别常见的 `IF`/`END-IF`、`EVALUATE`/`END-EVALUATE`、`PERFORM`/`END-PERFORM`、`READ`、`SEARCH`、`WRITE` 和 `EXEC` 块，也会参考 Area A/B 与数据级别。当前行按 `==`，全文件按 `gg=G`，选区按 `=` 重新缩进。固定序号区、指示区、注释和第 73 列后的标识区会受到保护。

自动缩进是启发式规则，不是完整 COBOL 解析器。复杂续行、编译器扩展语法或特殊版式后请检查列号和 `:CobolLint` 结果。

### 3. 注释切换和保留字大小写

固定格式用第 7 列的 `*` 标记整行注释，自由格式使用 `*>`。`gcc`、`<leader>c*` 和 Visual `gc` 会根据当前源格式切换注释。固定格式注释不会把第 7 列误当作普通缩进。

`:CobolFormatCase` 将范围内识别出的 COBOL 保留字转换为大写。先选中一段再运行命令，或直接运行以处理整个缓冲区：

~~~cobol
           move "move is text" to ws-message
           if ws-ready = "Y"
               display ws-message
           end-if
~~~

格式化器会保留字符串、注释和用户字段名；运行后仍应审阅结果，尤其是自定义词和编译器扩展。

### 4. 结构导航、返回与 Copybook

`gd` 是插件自己的 COBOL 定义跳转，不需要 COBOL LSP。它搜索当前程序和 `COPY` 引用的 Copybook，包含递归 Copybook。多个同名定义时会显示候选清单，按路径和行内容选择目标。

- `<C-o>` 返回调用点或原字段位置。
- `<C-i>` 向前重走刚才的跳转。
- `gf` 在 `COPY` 行打开 Copybook。
- `K` 在浮动窗口预览定义或 Copybook。

搜索目录来自 `.cobol.json` 的 `copybook_paths` 或插件设置。`COPY ... REPLACING` 会把 Copybook 名称与替换文本分开处理。

选装 Aerial 可显示 Division、Section、Paragraph、文件描述和 01 记录的大纲。Aerial 是另一个 Neovim 插件；没有它时 `gd`、`gf`、`K` 等导航仍然可用。

### 5. 数据名和关键字补全

安装 `blink.cmp` 后，插件会为 `cobol`、`cbl`、`cob` 自动注册补全源。候选包括 COBOL 关键字、动词、子句、代码片段、当前文件的数据名和过程名，以及被引用 Copybook 中的定义。不会启动 COBOL LSP。

试着输入 `PER`、`WS-`、`COPY`，观察候选；`Tab` / `Shift-Tab` 在候选或 snippet 占位符间移动，按 Enter 接受候选。具体接受键可能由 blink.cmp 配置调整。没有 blink.cmp 时，其他插件功能不受影响。

### 6. 折叠与上下文提示

插件根据 Division、Section、Paragraph 和 DATA 结构设置折叠。使用 Neovim 原生折叠键：

- `za`：切换当前折叠。
- `zc`：关闭当前折叠。
- `zo`：展开当前折叠。
- `zR`：展开全部。
- `zM`：折叠全部。

Winbar/状态上下文可显示源格式、Area、程序层级、当前字段 PIC 和字段/记录估算大小。其它状态栏框架也可调用：

~~~lua
local cobol_status = require("cobol.statusline")

-- Heirline、lualine 等组件可调用此函数。
{ cobol_status.component() }
~~~

或者由自定义 provider 调用 `require("cobol.statusline").get()`。非 COBOL 缓冲区返回空字符串。

### 7. 诊断、Quickfix、构建与运行

启用自动诊断时，插件异步调用 GnuCOBOL，不阻塞输入。默认保存后和编辑停止一小段时间后检查。`<leader>cl` / `:CobolLint` 可立即检查；`<leader>cq` / `:CobolQuickfix` 打开位置列表；`:cnext`、`:cprev` 在项目问题间移动。Copybook 中的错误会尽可能映射到 Copybook 文件和主程序中的 COPY 来源行。

单文件项目没有 Makefile 时：

- `:CobolTest` 用 `cobc -fsyntax-only` 检查语法。
- `:CobolBuild` 编译当前源文件。
- `:CobolRun` 编译后运行并清理临时可执行文件。

多文件程序请配置 Makefile 或 `.cobol.json` 命令。项目命令读取磁盘文件，执行前保存当前缓冲区。有 build 规则但没有明确 run 入口时，插件不会猜测要执行哪个程序。

## GnuCOBOL 项目配置

插件沿当前文件目录向上查找 `.cobol.json`、Makefile 或 Git 根目录。建议为固定格式 GnuCOBOL 项目在根目录建立 `.cobol.json`：

~~~json
{
  "source_format": "fixed",
  "dialect": "default",
  "compiler": "cobc",
  "copybook_paths": ["copy", "cpy"],
  "warnings": ["all", "no-obsolete"],
  "compiler_args": [],
  "commands": {
    "build": ["make", "build"],
    "run": ["make", "run"],
    "test": ["make", "test"]
  }
}
~~~

| 项目 | 含义 |
| --- | --- |
| `source_format` | `fixed`、`free` 或 `auto`；固定格式项目建议写 `fixed` |
| `dialect` | 可选 GnuCOBOL 方言，传递为 `-std=...` |
| `compiler` | 编译器可执行文件或路径，默认 `cobc` |
| `copybook_paths` | Copybook 目录；相对路径从项目根目录解析 |
| `warnings` | GnuCOBOL 警告名，例如 `all`、`no-obsolete` |
| `compiler_args` | 附加参数；每个数组元素是独立参数 |
| `commands.build/run/test` | 项目命令参数数组；省略时插件查找 Makefile 或使用单文件默认行为 |

命令以参数数组直接执行，不经过 shell 展开。需要管道或环境变量时，把逻辑写进 Makefile，再将 `commands` 指向 `make`。Makefile 自动识别 `build`/`all`、`run`、`test`/`check` 目标。多源文件项目应由自己的构建规则决定链接方式。

~~~make
.PHONY: build run test

build:
	cobc -x -fixed -I copy -o build/main src/MAIN.COB

run: build
	./build/main

test:
	cobc -fsyntax-only -fixed -I copy src/MAIN.COB
~~~

当 Makefile 使用自定义文件名、复杂链接方式或其他构建工具时，在 `.cobol.json` 的 `commands` 中明确指定命令。`run` 不会猜测程序入口。

### 全局插件配置

lazy.nvim 的 `opts` 可覆盖默认值：

~~~lua
{
  "iamcheyan/cobol.nvim",
  ft = { "cobol", "cbl", "cob" },
  opts = {
    source_format = "fixed",
    project_root = nil,
    copybook_paths = { ".", "./copy", "./cpy" },
    cobc_command = "cobc",
    cobc_extra_args = {},
    smart_tab = true,
    smart_comments = true,
    keymaps = true,
    folding = { enable = true },
    diagnostics = {
      enable = true,
      on_save = true,
      on_change = true,
      debounce_ms = 600,
    },
    completion = { enable = true },
  },
}
~~~

默认还启用列标尺、Winbar、面包屑、数据级别高亮、PIC/记录大小提示和第 72 列越界提示。`columns` 默认是 `{ 7, 8, 12, 73 }`。项目配置比全局选项更适合团队共享；不要把机器专属绝对路径提交到项目文件。

完整默认值速查：

| 选项 | 默认值 | 用途 |
| --- | --- | --- |
| `enabled` | `true` | 启用插件功能 |
| `columns` | `{ 7, 8, 12, 73 }` | 标尺列位置 |
| `show_lines` | `true` | 显示列细线标尺 |
| `char` | `"│"` | 标尺字符 |
| `show_winbar` | `true` | 显示顶部列刻度 |
| `show_breadcrumbs` | `true` | 显示 Division/Section/Paragraph 面包屑 |
| `show_hierarchy_hint` | `true` | 显示数据项父级提示 |
| `show_pic_size` | `true` | 显示字段/01 记录大小提示 |
| `highlight_levels` | `true` | 突出显示 01 和 88 级项目 |
| `show_colorcolumn` | `false` | 额外显示 Neovim ColorColumn；默认不用背景色块 |
| `highlight_overflow` | `true` | 高亮固定格式第 72 列以后的正文 |
| `overflow_col` | `72` | 正文安全边界列 |
| `disable_indent_guide` | `true` | 在 COBOL 窗口关闭通用缩进参考线 |
| `smart_tab` | `true` | 启用固定格式 Tab/反 Tab 列停靠 |
| `smart_comments` | `true` | 启用 COBOL 注释切换 |
| `keymaps` | `true` | 安装插件默认 buffer-local 快捷键 |
| `project_root` | `nil` | 可选项目根目录；未设时自动查找/回退 |
| `source_format` | `"auto"` | 固定格式、自由格式或自动识别 |
| `copybook_paths` | `{ ".", "./cpy", "./copy", "./copybooks", "./include", "../copybooks", "../include" }` | Copybook 搜索路径 |
| `cobc_command` | `"cobc"` | GnuCOBOL 编译器命令 |
| `cobc_extra_args` | `{}` | 附加 GnuCOBOL 参数 |
| `folding.enable` | `true` | 启用结构折叠 |
| `diagnostics.enable` | `true` | 启用编译器诊断 |
| `diagnostics.on_save` | `true` | 保存时检查 |
| `diagnostics.on_change` | `true` | 编辑时防抖检查 |
| `diagnostics.debounce_ms` | `600` | 编辑检查的延迟毫秒数 |
| `diagnostics.warnings` | `{ "all", "no-obsolete" }` | 默认警告选项 |
| `diagnostics.dialect` | `nil` | 可选方言；项目 profile 可覆盖 |
| `diagnostics.copybook_paths` | `nil` | 为空时继承顶层 Copybook 路径 |
| `completion.enable` | `true` | 启用可选补全源；仍需安装 blink.cmp |

## COBOL 入门练习

建议先安装 GnuCOBOL 并准备一个目录：

~~~sh
mkdir -p ~/cobol-study
cd ~/cobol-study
nvim HELLO.COB
~~~

每完成一题都用插件功能检查，再用编译器验证。固定格式示例请保持每行开头的空格数量。

### 练习一：输出一句话，熟悉列号和运行

输入并保存为 `HELLO.COB`：

~~~cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HELLO.
       PROCEDURE DIVISION.
           DISPLAY "HELLO, COBOL".
           STOP RUN.
~~~

操作：

1. 用 `g8` 检查程序身份行的起始列，用 `g12` 检查 DISPLAY 语句。
2. 运行 `:CobolLint`，确认没有语法错误。
3. 运行 `:CobolRun`，观察输出并理解 `STOP RUN`。
4. 删除 `DISPLAY` 行末尾的句点再检查，观察报错位置，然后恢复。

### 练习二：声明字段并使用条件名

~~~cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GREETING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-NAME PIC X(20) VALUE "COBOL".
       01 WS-COUNT PIC 9(3) VALUE ZERO.
          88 WS-COUNT-IS-ZERO VALUE ZERO.
       PROCEDURE DIVISION.
           IF WS-COUNT-IS-ZERO
               DISPLAY "HELLO, " WS-NAME
           END-IF.
           STOP RUN.
~~~

操作：在 `WS-NAME` 或 `WS-COUNT-IS-ZERO` 上按 `gd`；观察 01/88 高亮和父级提示；输入 `WS-` 看补全候选。`PIC X(20)` 表示 20 个字符位置，`PIC 9(3)` 表示 3 位数字。运行 `:CobolRun`。

思考：如果把 `WS-COUNT` 初始值改成 1，条件名还会成立吗？怎样给 IF 增加 ELSE 分支？

### 练习三：阅读嵌套记录和估算 PIC 长度

~~~cobol
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INPUT-RECORD.
          05 WS-ACCOUNT-NO PIC 9(6).
          05 WS-CUSTOMER-NAME PIC X(20).
          05 WS-BALANCE PIC S9(7)V99 COMP-3.
          05 WS-ACTIVE PIC X VALUE "Y".
~~~

操作：

1. 光标放在 `01 WS-INPUT-RECORD`，运行 `:CobolCalcRecord`。
2. 对照字段列表读偏移量：每个字段从记录开头的哪个字节位置开始。
3. 光标移到各 PIC 字段，阅读行尾的字段大小提示。
4. 临时把 `COMP-3` 改为显示用法，再算一次并比较。

计算器适合学习和初步核对。COMP、COMP-3、符号位、SYNC、编译器版本和目标平台可能改变实际布局；生产文件长度应以目标环境的编译器与平台规则为准。

### 练习四：PERFORM、段落跳转和折叠

~~~cobol
       PROCEDURE DIVISION.
       MAIN-PROCEDURE.
           PERFORM 1000-SAY-HELLO
           STOP RUN.
       1000-SAY-HELLO.
           DISPLAY "THIS IS A PARAGRAPH".
~~~

操作：在 `PERFORM 1000-SAY-HELLO` 的段落名上按 `gd`，按 `<C-o>` 返回，再按 `<C-i>` 前进。将光标放到 `1000-SAY-HELLO.`，按 `za` 折叠或展开段落。用 `gg=G` 重新缩进后检查 Area A/B。

学习目标：`PERFORM` 调用过程段落；段落名是定义；跳转列表可以在调用与定义间来回。插件解析常见结构，不是完整 COBOL 语言服务器。

### 练习五：IF、EVALUATE 和缩进

将 `PROCEDURE DIVISION` 中的逻辑改为：

~~~cobol
           IF WS-ACTIVE = "Y"
               EVALUATE WS-COUNT
                   WHEN ZERO
                       DISPLAY "EMPTY"
                   WHEN OTHER
                       DISPLAY "HAS DATA"
               END-EVALUATE
           ELSE
               DISPLAY "INACTIVE"
           END-IF.
~~~

用 `==` 重新缩进当前行；或选择代码后按 `=`。检查 WHEN、ELSE、END-EVALUATE、END-IF 是否在正确层级。然后故意拼错 END-IF，用 `:CobolLint` 看诊断。

### 练习六：建立 Copybook 并从程序跳转

创建 `copy/CUSTOMER-REC.CPY`：

~~~cobol
       01 CUSTOMER-RECORD.
          05 CUSTOMER-ID PIC 9(6).
          05 CUSTOMER-NAME PIC X(30).
~~~

在主程序 DATA DIVISION 中引用：

~~~cobol
       COPY "CUSTOMER-REC.CPY".
~~~

操作：在 COPY 行按 `gf` 打开文件，再按 `<C-o>` 返回；在 `CUSTOMER-ID` 上按 `gd` 跳到定义；按 `K` 预览。增加字段后，回主程序输入字段前缀检查补全。

如果找不到文件，检查项目根目录和 `copybook_paths`。搜索路径也会用于 GnuCOBOL 的 `-I` 参数。

### 练习七：表格 OCCURS 和遍历

在 WORKING-STORAGE 中增加：

~~~cobol
       01 WS-ITEM-TABLE.
          05 WS-ITEM OCCURS 3 TIMES.
             10 WS-ITEM-CODE PIC X(5).
             10 WS-ITEM-QTY PIC 9(3).
~~~

用 `gd` 找 `WS-ITEM-QTY`，用折叠查看层级，并运行 `:CobolCalcRecord` 观察 PIC 项估算。尝试为 3 个项目赋值/显示字段，再用 `PERFORM VARYING` 遍历。

计算器为 PIC 字段和常见 OCCURS/REDEFINES 提供估算；复杂嵌套组、`OCCURS DEPENDING ON`、对齐和编译器扩展应通过目标编译器或项目工具确认。

### 练习八：诊断、Quickfix 和错误修复循环

暂时加入一个拼错的字段名：

~~~cobol
           DISPLAY WS-CUSTOMER-NMAE
~~~

保存并等待自动诊断，或运行 `:CobolLint`；运行 `:CobolQuickfix`，用 `:cnext` / `:cprev` 浏览；修正字段名，再检查一次确认旧诊断消失。再把错误移到 Copybook 中，观察主程序 COPY 行和已打开 Copybook 中的提示。

没有安装 `cobc` 时，插件仍可提供编辑和导航；诊断与编译器构建需要 GnuCOBOL。

### 练习九：项目构建循环

把练习文件放进 Git 项目根目录，创建 `.cobol.json` 和 Makefile。设置 `source_format` 为 `fixed`、Copybook 目录为 `copy`，依次运行：

~~~vim
:CobolTest
:CobolBuild
:CobolRun
~~~

修改 Makefile 的 `test` 目标使它检查 Copybook；再制造语法错误，确认 Quickfix 显示位置。最后把 `commands` 改成项目真正的编译、运行和测试参数。

## PIC 与记录长度估算

下面是插件使用的常见近似规则：

| 用法 | 插件估算方式 |
| --- | --- |
| `PIC X(20)`、`PIC A(10)` | 每个字符位置按 1 字节 |
| `PIC 9(5)V99` | `V` 是隐含小数点，不占显示存储；数字按字符位计数 |
| `PIC S9(7) COMP-3` | 按数字半字节与符号半字节估算压缩十进制 |
| `PIC 9(n) COMP` / `BINARY` | 按数字位数粗分为 2、4 或 8 字节 |
| `COMP-1` / `COMP-2` | 常见实现按 4 / 8 字节估算 |
| `OCCURS n` | 字段估算值乘以重复次数 |
| `REDEFINES` | 布局表标记与重定义字段共享起始位置 |
| 88 级条件名 | 不占独立存储 |

光标在数据字段上时会显示局部估算；在 01 行运行 `:CobolCalcRecord` 可打开布局表。估算不是 ABI 保证：不同 GnuCOBOL 版本、编译参数、平台、同步对齐、独立符号位和高级 OCCURS 选项都会影响实际长度。需要精确文件长度时，用目标平台的编译器工具和定义规范验证。

## 常见问题

**没有列标尺或快捷键。** 检查 `:set filetype?`；插件只在 `cobol`、`cbl`、`cob` filetype 附着。运行 `:verbose nmap gd` 查看映射来源，并确认全局 `keymaps` 没有关闭。

**`gd` 跳不到变量或跳到多个候选。** 检查定义是否符合 COBOL 数据级别/段落格式、Copybook 是否由 `COPY` 引用、搜索目录是否正确。多个同名定义会要求你选择。按 `<C-o>` 回到跳转前位置。

**`gf` 找不到 Copybook。** 检查文件名和大小写；Linux 文件系统大小写敏感。确认 `.cobol.json` 路径相对项目根目录，且 Copybook 位于搜索目录。

**没有自动诊断。** 运行 `:echo executable('cobc')`；返回 0 表示 Neovim 没在 PATH 找到编译器。再检查 `:CobolDiagnosticsToggle` 状态及 `diagnostics.enable`。

**没有 Aerial 大纲或 Blink 补全。** 它们是可选插件；分别检查对应插件是否安装并加载。它们不是 `cobol.nvim` 的硬依赖。

**缩进看起来不对。** 缩进是启发式的；确认源格式为 fixed，并检查列 1–7、72 列边界、续行和编译器诊断。未识别的写法要手动校正。

**记录字节数和实际文件长度不同。** 计算器是学习辅助和近似估算。检查方言、USAGE、SIGN、SYNC、REDEFINES、OCCURS 和目标 ABI，不要只根据虚拟提示修改生产记录布局。

## 文档与开发

- 本文 `README.zh-CN.md`：完整中文学习和使用手册。
- `README.md` / `README.ja.md`：英文和日文入口。
- `doc/cobol.nvim.txt`：Neovim 原生帮助页，使用 `:help cobol.nvim`、`:help cobol-commands` 等标签。
- 开发者验证：在插件根目录运行 `./scripts/test.sh`。

本项目采用 MIT License，见 [LICENSE](LICENSE)。
