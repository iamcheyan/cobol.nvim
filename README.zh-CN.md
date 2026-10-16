# cobol.nvim

为 Neovim 提供 COBOL 编辑支持：固定格式列标尺与缩进、Copybook/定义跳转、Tree-sitter 结构提示、记录长度估算、可选补全和 GnuCOBOL 诊断。不需要 COBOL 语言服务器。

[English](README.md) · [日本語](README.ja.md) · Neovim 帮助：`:help cobol.nvim`

![Syms 大纲及 IF/ELSE/END-IF 结构提示](assets/image-20261016-111954.png)

截图中的 Syms 是另行配置的大纲界面；插件自带的是 Aerial 的 COBOL 后端。编辑区显示列标尺、当前已配对 IF 块的彩色起止/分支标记及连接虚线，顶部为 Winbar。主题和布局由个人 Neovim 配置决定。

## 安装与依赖

需要 Neovim 0.10+。使用 lazy.nvim：

```lua
{
  "iamcheyan/cobol.nvim",
  ft = { "cobol", "cbl", "cob" },
  build = "bash scripts/build_parser.sh", -- 可选：安装时编译 Tree-sitter 解析器
  opts = {},
}
```

- 插件会在启动时尝试用 `gcc`、`clang` 或 `cc` 编译缺失的 COBOL Tree-sitter 解析器；也可在插件目录执行 `./scripts/build_parser.sh`。AST 结构功能需要解析器；若已有可用的 `cobol.so`，运行时不必再安装 C 编译器。
- GnuCOBOL (`cobc`) 用于诊断及编译/运行，插件不会安装它；[blink.cmp](https://github.com/saghen/blink.cmp) 用于可选补全。未安装这两个依赖时，其他编辑功能仍可使用。
- Aerial 大纲是可选的，需另行安装。下面的 lazy.nvim 配置启用本插件提供的 COBOL 后端：

```lua
{
  "stevearc/aerial.nvim",
  opts = function(_, opts)
    opts.backends = vim.tbl_deep_extend("force", opts.backends or {}, {
      cobol = { "cobol" },
    })
  end,
}
```

使用 `:AerialToggle` 打开大纲；本插件不提供 `<leader>cs` 等默认大纲快捷键，需自行映射。Syms 则应按 Syms 自身说明配置。

插件附着于 `cobol`、`cbl`、`cob` filetype。打开 `.cob`、`.cbl`、`.cobol` 或 Copybook 后，用 `:set filetype?` 确认当前 filetype；遇到未识别的 `.cpy`，按自己的 Neovim filetype 配置设为 `cobol`。

## 快速上手

下面是一个**固定格式**示例，行首空格是源码格式的一部分：

```cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEMO.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-STATUS PIC X VALUE "Y".
       PROCEDURE DIVISION.
           IF WS-STATUS = "Y"
               DISPLAY "READY"
           END-IF.
           STOP RUN.
```

1. 打开文件，看第 7/8/12/73 列标尺；按 `g8` 或 `g12` 跳到对应区域。把光标放在 `WS-STATUS` 上按 `gd` 跳转，按 `<C-o>` 返回。
2. 把光标放在 `IF` 或 `END-IF` 上按 `%` 跳到配对关键字；选中 IF 块可用 `vaf`，其内部用 `vif`。光标置于块内时查看彩色作用域标记和 Winbar。
3. 在 `01 WS-STATUS` 上运行 `:CobolCalcRecord` 查看估算；有 `cobc` 时运行 `:CobolLint`，再用 `:CobolQuickfix` 查看问题。`za` 可折叠 Division、Section、Paragraph 或数据项。

如果程序使用 `COPY "CUSTOMER.CPY".`，在 Copybook 名称上按 `gf` 打开，按 `K` 预览，程序中的字段引用可用 `gd` 定位定义。将 Copybook 路径放入 `copybook_paths`，才能搜索到非默认目录的文件。

## 功能说明

### 固定格式与编辑

固定格式的 1–6 列是序号区，7 列是指示区（`*` 注释、`/` 换页、`-` 续行），8–11 列为 Area A，12–72 列为 Area B，73 列起是标识区。插件默认在 7、8、12、73 列画细线，并高亮第 72 列后的内容；`g7`、`g8`、`g12`、`g73` 跳到相应列，必要时会填充短行。`:CobolGuideToggle` 开关视觉提示与诊断附着；关闭时清理当前诊断，但保留已安装的映射和折叠设置。也可用 `:CobolGuideEnable` / `:CobolGuideDisable`。

`source_format` 可设为 `auto`（默认，无法识别时按固定格式）、`fixed` 或 `free`。固定格式的 Insert `<Tab>` 在光标前只有空白时依次停靠 7、8、12 列，之后按 `shiftwidth` 缩进；`<S-Tab>` 反向停靠。自由格式不用固定列停靠。缩进表达式识别常见的 IF/EVALUATE/PERFORM/READ/SEARCH/WRITE/EXEC 块及数据级别；`==`、Visual `=`、`gg=G` 可重缩进。续行、注释、序号/指示区和 73–80 列标识区会受保护；缩进仍是启发式的，请检查编译结果。

`gcc`（可带数量）、Visual `gc`、`<leader>c*` 和 `:CobolToggleComment` 切换注释：固定格式在第 7 列用 `*`，自由格式用 `*>`；命令可指定行范围。`:CobolFormatCase` 把识别到的保留字转为大写，保留字符串、注释和用户定义名；**不带范围处理整个缓冲区**，指定行范围才只处理该范围，它不是完整的源码格式化器。

### 定义与 Copybook 导航

`gd` / `:CobolGotoDef` 搜索当前文件及递归引用的 Copybook 中的段落、Section 和数据定义；多个候选可选择。`gf` / `:CobolGotoCopybook` 打开 `COPY` 语句引用的文件；`K` / `:CobolPreview` 浮窗预览定义或 Copybook，`<C-o>` / `<C-i>` 沿 Neovim 跳转列表返回或前进。搜索支持区分 `COPY ... REPLACING` 的文件名和替换文本。路径来自 `copybook_paths` 或项目 profile，不需要 LSP。当前定义索引对不带固定格式列前缀的自由格式声明有局限；找不到时请核对源格式及 Copybook 搜索路径。

### Tree-sitter 结构视图

解析器可用时，插件在光标所在的**最内层已配对结构**上显示彩色开始/结束标记、连接虚线，以及 ELSE/WHEN 分支标记。配置 `structure_scope = { enable = true, char = "┆", show_branches = true }` 可分别控制开关、线条字符和分支标记。嵌套结构不会同时高亮所有层。支持 IF、EVALUATE、PERFORM、SEARCH、READ、WRITE、REWRITE、DELETE、START、STRING、UNSTRING，以及 XML PARSE、JSON PARSE、EXEC SQL、CLASS-ID、METHOD-ID、FACTORY、OBJECT 的配对。

Winbar 的面包屑显示 Division → Section → Paragraph → 控制结构 → WHEN 等上下文，空间不足时保留靠近光标的层级；完整层级可用 `:lua require("cobol.ast").show_breadcrumb_float()` 查看。右侧列出当前位置**已解析且已配对**块对应的结束关键字（从内到外）。`:CobolStructure` 通过**通知**显示这些关键字；浮窗形式是 `:lua require("cobol.ast").show_waiting_closures_float()`。它不是缺失 `END-*` 的检查器：无法配对的块通常不会出现在列表里，请用 `:CobolLint` 检查语法。

`%` 在上述结构起止关键字间双向跳转，无匹配时回退到 Neovim 行为。`af`/`if`、`ae`/`ie`、`ap`/`ip` 分别是 IF、EVALUATE、PERFORM 的内外文本对象，可用于 Visual（如 `vaf`）或操作符（如 `daf`）。这些能力都需要可用的解析器。

### 大纲、折叠与上下文

可选 Aerial 后端提供 Division、Section、Paragraph、程序 ID、FD/SD、01 记录，以及解析器支持的控制结构、分支、文件操作、调用和嵌入 SQL 等层级符号。截图里的 Syms 是另一个由用户自行配置的大纲 UI，不是本插件自带的 Syms 后端。

插件的原生 `foldexpr` 折叠 Division、Section、Paragraph 和数据项（`za` / `zc` / `zo`）；**不自行创建 IF/EVALUATE 等控制块的折叠**。如果其他折叠提供者生成了控制块折叠，AST 可改善其摘要。`folding.foldtext` 取 `"auto"`（默认，nvim-ufo 管理时让出）、`"plugin"` 或 `"off"`。Winbar、数据父级提示、PIC 大小提示和 01/88 级别高亮提供额外上下文；如需在自有状态栏显示格式、Area、层级、字段及估算大小，可用 `require("cobol.statusline").component()` 或 `.format()`。可选 contextline 集成在对应插件存在时注册。

### 补全与记录长度估算

安装 blink.cmp 后，插件为 `cobol`、`cbl`、`cob` 注册补全源，包括关键字、常见语句片段、当前文件及引用 Copybook 中的数据名和段落等。不安装 blink.cmp 不影响其他功能。补全是基于启发式解析的建议，不等于 COBOL LSP。

`<leader>cr` / `:CobolCalcRecord` 显示当前数据项或 01 记录的字段/偏移量估算。覆盖 DISPLAY、COMP/BINARY、COMP-3/PACKED-DECIMAL、COMP-1/2、基本字段的 OCCURS、REDEFINES；88 级条件名不占独立存储。**组级 OCCURS 不会使子项总长重复计数，更大的 REDEFINES 覆盖项也不会增加估算总长**。对齐、符号位、方言、ABI 等亦会改变实际存储长度；生产布局须以目标编译器验证。

### 诊断、构建与运行

自动诊断异步运行 `cobc -fsyntax-only`：默认在保存、编辑防抖（600 ms）及退出 Insert 后检查；可用 `<leader>cl` / `:CobolLint` 立即执行，`<leader>cq` / `:CobolQuickfix` 打开 Quickfix，`:cnext` / `:cprev` 浏览结果。尽可能将 Copybook 错误映射到打开的 Copybook 和主程序的 COPY 行，未保存内容尽可能通过标准输入交给编译器。`:CobolDiagnosticsToggle` 开关自动诊断。没有 `cobc` 时编辑功能仍可使用，但无法完成实际编译检查。

`:CobolBuild`、`:CobolRun`、`:CobolTest` 异步执行项目命令或 Makefile 的 `build`/`all`、`run`、`test`/`check` 目标；单文件无构建规则时回退到 `cobc` 编译、运行或语法检查。它们读取磁盘文件，执行前先保存。多文件项目应提供构建规则；项目有 build 目标但无 run 入口时不会猜测执行哪个程序。

## 项目配置与默认选项

插件从当前文件向上查找 `.cobol.json`、Makefile 或 Git 根目录。项目 profile 可共享格式、编译器、方言、Copybook 路径及项目命令；缺失时使用插件默认值，JSON 或字段无效时发出警告并回退：

```json
{
  "source_format": "fixed",
  "compiler": "cobc",
  "copybook_paths": ["copy", "cpy"],
  "dialect": "default",
  "warnings": ["all", "no-obsolete"],
  "compiler_args": [],
  "commands": {
    "build": ["make", "build"],
    "run": ["make", "run"],
    "test": ["make", "test"]
  }
}
```

相对路径从项目根目录解析；命令为参数数组，**不经过 shell**。不需要项目 profile 时，在 lazy.nvim 的 `opts` 配置插件即可。以下按功能列出常用的有效选项及默认值，完整参考见 `:help cobol-configuration`：

| 类别 | 选项及默认值 |
| --- | --- |
| 视觉 | `columns = {7,8,12,73}`、`show_lines = true`、`char = "│"`、`show_winbar = true`、`show_breadcrumbs = true`、`show_waiting_closures = true` |
| 结构 | `structure_scope = { enable = true, char = "┆", show_branches = true }` |
| 数据提示 | `show_hierarchy_hint = true`、`show_pic_size = true`、`highlight_levels = true` |
| 越界/缩进线 | `highlight_overflow = true`（边界固定为第 72 列）、`show_colorcolumn = false`、`disable_indent_guide = true` |
| 编辑 | `smart_tab = true`、`keymaps = true`、`source_format = "auto"` |
| 项目 | `project_root = nil`（无效路径会回退）、`copybook_paths`（含 `.`, `./cpy`, `./copy`, `./copybooks`, `./include`, `../copybooks`, `../include`）、`cobc_command = "cobc"`、`cobc_extra_args = {}` |
| 折叠 | `folding = { enable = true, foldtext = "auto" }` |
| 诊断 | `diagnostics = { enable = true, on_save = true, on_change = true, debounce_ms = 600, warnings = {"all", "no-obsolete"}, dialect = nil, copybook_paths = nil }` |
| 补全 | `completion = { enable = true }`（需安装 blink.cmp） |

源码中还声明了 `enabled`、`overflow_col`、`smart_comments`，但目前未按其值控制对应行为，请不要依赖这三个开关。`keymaps = false` 关闭插件默认映射；`<leader>` 由用户的 Neovim 配置决定。

## 快捷键与命令速查

| 默认映射 | 功能 |
| --- | --- |
| `g7` / `g8` / `g12` / `g73` | 固定格式列跳转 |
| `gd` / `gf` / `K` | 定义跳转 / 打开 Copybook / 浮窗预览 |
| `gcc` / Visual `gc` / `<leader>c*` | 注释切换 |
| Insert `<Tab>` / `<S-Tab>` | 固定格式列停靠与反向停靠 |
| `%` | 有解析器时跳到配对结构，无匹配时回退 |
| Visual/操作符 `af` / `if`、`ae` / `ie`、`ap` / `ip` | IF、EVALUATE、PERFORM 的内外文本对象 |
| `<leader>cr` / `<leader>cl` / `<leader>cq` | 布局估算 / 立即检查 / 打开 Quickfix |

| 命令 | 功能 |
| --- | --- |
| `:CobolGuideToggle` / `:CobolGuideEnable` / `:CobolGuideDisable` | 切换视觉提示及诊断附着（不卸载映射/折叠） |
| `:CobolToggleComment` / `:CobolFormatCase` | 注释切换 / 范围或全缓冲区保留字大写 |
| `:CobolGotoDef` / `:CobolGotoCopybook` / `:CobolPreview` | 定义跳转 / Copybook / 预览 |
| `:CobolCalcRecord` / `:CobolStructure` | 字段估算 / 已配对块结束关键字通知 |
| `:CobolLint` / `:CobolQuickfix` / `:CobolDiagnosticsToggle` | 语法检查 / Quickfix / 自动诊断开关 |
| `:CobolBuild` / `:CobolRun` / `:CobolTest` | 构建 / 运行 / 测试 |

## 排查与开发

- 没有标尺或映射：检查 `:set filetype?`、`:verbose nmap gd` 和 `keymaps`。
- 没有结构标记或 `%` 配对：检查 COBOL Tree-sitter 解析器；没有大纲则确认 Aerial/Syms 自行安装配置。
- 没有诊断：检查 `:echo executable('cobc')`、`cobc_command`，并确认未关闭诊断。
- 找不到 Copybook：检查项目根目录与 `copybook_paths`；估算长度异常时用目标编译器核实。

仓库根目录运行 `./scripts/test.sh` 执行插件测试（未安装 Aerial 时其专用测试会跳过）。许可证见 [LICENSE](LICENSE)。
