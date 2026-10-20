# cobol.nvim

为 Neovim 提供 COBOL 编辑支持：固定格式列标尺、定义与 Copybook 导航、Tree-sitter 结构提示、记录长度估算、可选补全和 GnuCOBOL 诊断。不需要 COBOL 语言服务器。

[English](README.md) · [日本語](README.ja.md) · Neovim 帮助：`:help cobol.nvim`

![固定格式标尺、Winbar 面包屑与当前行记录长度](assets/fixed-format-ruler.png)

截图展示插件处理一个固定格式程序：7/8/12/73 列标尺、Winbar 面包屑（`DATA DIVISION`），以及光标所在行显示的记录长度估算。主题与布局由个人 Neovim 配置决定。

## 功能一览

| 类别 | 提供什么 | 截图 |
| --- | --- | --- |
| 固定格式布局 | 7、8、12、73 列细线标尺，列跳转，第 72 列越界高亮 | 上方 |
| IBM z/OS 大型机实用工具 | 行序号管理（`:CobolRenum`/`:CobolUnnum`）、EBCDIC/Nibble/COMP-3 检查窗（`:CobolHex`）、Smart CAPS 智能大写输入（`:CobolCapsToggle`） | [文档](docs/MAINFRAME_ISPF_GUIDE.md) |
| 结构大纲 | 大纲侧栏中的 Division / Section / Paragraph / 控制结构 / 数据层级树 | [见下](#结构大纲与作用域提示) |
| 定义与 Copybook 导航 | `gd`、`gf`、`K` 预览、跳转列表返回 | [见下](#定义与-copybook-导航) |
| 记录长度计算 | `:CobolCalcRecord` 输出 DISPLAY / COMP / COMP-3 / OCCURS / REDEFINES 布局表 | [见下](#pic-与记录长度计算) |
| 诊断 | 异步 `cobc -fsyntax-only`，行内提示与 Quickfix | [见下](#诊断) |
| 折叠与格式化 | 按 Division / Section / Paragraph / 数据项折叠，保留字大写 | [见下](#折叠与格式化) |

## 适用对象

学习固定格式 COBOL 的初学者、维护 `.cob` / `.cbl` / `.cobol` 程序的开发者，以及使用 Copybook 和传统 Division / Section / Paragraph 结构的项目。

## 依赖

- Neovim 0.10 或更高版本。
- 编译自带 Tree-sitter 解析器需要 C 编译器（`gcc`、`clang` 或 `cc`）。插件会在启动时尝试编译缺失的解析器；AST 功能需要可用的解析器，但 `cobol.so` 已存在时运行期不再需要编译器。
- 可选：[blink.cmp](https://github.com/saghen/blink.cmp) 用于补全，GnuCOBOL（`cobc`）用于诊断与构建运行，Aerial 或 Syms 用于大纲侧栏。

## 安装

使用 [lazy.nvim](https://github.com/folke/lazy.nvim)：

```lua
{
  "iamcheyan/cobol.nvim",
  build = "bash scripts/build_parser.sh", -- 可选：安装时预编译 Tree-sitter 解析器
  ft = { "cobol", "cbl", "cob" },
  opts = {},
}
```

不加 `build` 钩子时，插件仍会在启动时尝试编译缺失的解析器。若系统中没有 C 编译器，请安装后再执行一次 `./scripts/build_parser.sh`。

需要可选的大纲侧栏时，安装 Aerial 并启用 COBOL 后端：

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

插件不提供默认的大纲快捷键，请自行映射，例如：

```lua
vim.keymap.set("n", "<leader>cs", "<cmd>AerialToggle<CR>", { desc = "Toggle outline" })
```

插件附着于 `cobol`、`cbl`、`cob` filetype。遇到未识别的 `.cpy`，用 `:set filetype?` 确认后按需设为 `cobol`。

## 快速上手

把下面内容保存为**固定格式**的 `.cob` 文件，行首空格是源码格式的一部分：

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

1. 打开文件看列标尺；`g8`、`g12` 分别跳到 Area A、Area B。
2. 光标放在 `WS-STATUS` 上按 `gd` 跳转，`<C-o>` 返回；在 `IF` 或 `END-IF` 上按 `%` 跳到配对关键字。
3. 在 `01` 数据项上运行 `:CobolCalcRecord`；装了 `cobc` 时运行 `:CobolLint`，再用 `:CobolQuickfix` 查看问题；`za` 折叠当前 Division、Section、Paragraph 或数据项。

## 固定格式与编辑

固定格式中，1–6 列是序号区，第 7 列是指示区（`*` 注释、`/` 换页、`-` 续行），8–11 列是 Area A，12–72 列是 Area B，73 列起是标识区。插件在 7、8、12、73 列绘制细线，并高亮第 72 列之后的内容——固定格式编译器会忽略该区域的源码。

| 按键 | 目标列 |
| --- | --- |
| `g7` | 指示符区 |
| `g8` | Area A |
| `g12` | Area B |
| `g73` | 标识区 |

固定格式下，光标前只有空白时，Insert `<Tab>` 依次停靠第 7、8、12 列，之后按 `shiftwidth` 缩进；`<S-Tab>` 反向停靠且不删除源码文本。自由格式没有列停靠。

`:CobolGuideToggle` 开关视觉提示与诊断附着，`:CobolGuideEnable` / `:CobolGuideDisable` 分别重新附着或解除（解除时同时清理当前诊断）。已安装的映射与折叠设置不受影响。

`gcc`、Visual `gc`、`<leader>c*` 和 `:CobolToggleComment` 按识别出的源格式切换注释：固定格式在第 7 列用 `*`，自由格式用 `*>`；命令可指定行范围。`:CobolFormatCase` 把识别到的保留字转为大写，保留字符串、注释和用户定义名；不带范围时处理整个缓冲区。

## 结构大纲与作用域提示

![Aerial 大纲、固定格式标尺与 Winbar 面包屑](assets/outline-aerial.png)

大纲侧栏是可选的（Aerial 或 Syms），插件自带 Aerial 的 COBOL 后端。该后端识别 Division、Section、Paragraph、程序 ID、FD/SD、01 级记录，解析器可用时还包括控制结构、分支、文件操作、调用和嵌入 SQL。未安装大纲插件时，其他功能仍可正常使用。

![已配对 IF / ELSE / END-IF 的作用域标记，以及大纲侧栏](assets/image-20261016-111954.png)

上图的大纲侧栏使用 Syms（Aerial 或 Syms 均可）。编辑区中当前 `IF ... ELSE ... END-IF` 块由彩色起始、分支与结束标记以及竖直虚线标出，顶部为 Winbar 面包屑。

解析器可用时，插件还会在光标所在的**最内层已配对结构**上绘制彩色起止标记、连接虚线以及 `ELSE` / `WHEN` 分支标记。支持的配对包括 `IF`、`EVALUATE`、`PERFORM`、`SEARCH`、`READ`、`WRITE`、`REWRITE`、`DELETE`、`START`、`STRING`、`UNSTRING`，以及 `XML PARSE`、`JSON PARSE`、`EXEC SQL`、`CLASS-ID`、`METHOD-ID`、`FACTORY`、`OBJECT`。

配置项：

```lua
structure_scope = { enable = true, char = "┆", show_branches = true }
```

Winbar 面包屑显示 `Division > Section > Paragraph > 控制结构 > WHEN`；完整层级可用 `:lua require("cobol.ast").show_breadcrumb_float()` 查看。`:CobolStructure` 报告光标处期望的 `END-*` 关键字（从内到外），浮窗形式是 `:lua require("cobol.ast").show_waiting_closures_float()`。它**不是**缺失终止符检查器——无法配对的块通常不会出现——请用 `:CobolLint` 检查语法。

`%` 在上述结构的起止关键字之间双向跳转，无匹配时回退到 Neovim 默认行为。文本对象 `af`/`if`、`ae`/`ie`、`ap`/`ip` 分别选中 `IF`、`EVALUATE`、`PERFORM` 块的内部或整体（如 `vaf`、`daf`）。

## 定义与 Copybook 导航

![按 `K` 在浮窗中预览 Copybook](assets/copybook-preview.png)

- `gd` / `:CobolGotoDef`：搜索当前文件及递归引用的 Copybook；多个候选时可选。
- `gf` / `:CobolGotoCopybook`：打开 `COPY` 语句引用的文件。
- `K` / `:CobolPreview`：在浮窗中预览定义或 Copybook，即上图所示。
- `<C-o>` / `<C-i>`：沿 Neovim 跳转列表后退或前进。

路径来自 `copybook_paths` 或项目 profile，不需要语言服务器。当前定义索引对不带固定格式列前缀的自由格式声明有局限，找不到时请核对源格式与搜索路径。

## PIC 与记录长度计算

![`:CobolCalcRecord` 列出字段偏移、PIC、长度与记录总长](assets/record-layout.png)

`<leader>cr` 或 `:CobolCalcRecord` 为当前记录或字段打开布局表，估算常见的 `DISPLAY`、`COMP`/`BINARY`、`COMP-3`/`PACKED-DECIMAL`、`OCCURS` 与 `REDEFINES` 声明，即上图所示。

这些数值是基于常见 GnuCOBOL 与平台约定的**估算**；真实 ABI 与存储布局仍以编译器为准。特别是组级 `OCCURS` 不会使子项总长重复计数，更大的 `REDEFINES` 覆盖项也不会增加估算总长，请据此理解报表中的总长。

## 诊断

![保存后行内报告编译器错误](assets/diagnostics.png)

插件执行：

```text
cobc -fsyntax-only ...
```

检查在保存后、编辑防抖后以及退出 Insert 模式时异步运行。`<leader>cl` 或 `:CobolLint` 立即执行一次，`<leader>cq` 或 `:CobolQuickfix` 打开 Quickfix 列表，`:CobolDiagnosticsToggle` 开关自动诊断。未保存的内容尽可能通过标准输入交给编译器。缺少 `cobc` 时插件不会崩溃；请安装 GnuCOBOL 或设置 `cobc_command`。

## 折叠与格式化

![按 Division、Section、Paragraph 折叠程序](assets/folding.png)

插件为 Division、Section、Paragraph 和数据项提供原生折叠：`za` 切换、`zc` 关闭、`zo` 打开，即上图所示。`IF`/`EVALUATE` 等控制块折叠来自其他折叠提供者；当它们存在时，解析器可改善其摘要，而不是显示原始行数。

`folding.foldtext` 决定折叠文本的归属：

| 取值 | 行为 |
| --- | --- |
| `"auto"`（默认） | 安装 COBOL 摘要，除非该缓冲区由 nvim-ufo 管理。 |
| `"plugin"` | 始终使用 COBOL 结构摘要。 |
| `"off"` | 不修改 `foldtext`。 |

固定格式缓冲区对常见块和数据级别使用 COBOL 感知缩进；`gg=G` 重排整个文件，Visual `=` 重排选区。序号/指示符行、续行、注释以及 73–80 列的非空标识区文本会被保留。

## 补全

安装 `blink.cmp` 后，插件为 `cobol`、`cbl`、`cob` 缓冲区注册补全源：常见动词与子句、可直接展开的片段（如 `IF ... END-IF`、`PERFORM ... END-PERFORM`）、缓冲区中声明的名称，以及引用 Copybook 中的符号。补全不区分大小写，在输入 `PER`、`WS-`、`COPY` 等前缀后最有用。补全是可选的，不安装不影响其他功能。

## 项目配置

在项目根目录创建 `.cobol.json`：

```json
{
  "source_format": "fixed",
  "dialect": "default",
  "compiler": "cobc",
  "copybook_paths": ["copy", "cpy"],
  "warnings": ["all", "no-obsolete"],
  "compiler_args": ["-Wall"],
  "commands": {
    "build": ["make", "build"],
    "run": ["make", "run"],
    "test": ["make", "test"]
  }
}
```

相对路径从发现的项目根目录解析，导航、补全、诊断和单文件构建共用同一份 Copybook 路径、编译器、格式、方言与额外参数。profile 是可选的：没有 `.cobol.json` 时静默使用默认值；JSON 或字段无效时给出警告并回退到安全默认值。命令值为参数数组，**不经过 shell**。未显式配置命令时，插件识别 Makefile 的 `build`/`all`、`run`、`test`/`check` 目标；无 Makefile 的单源文件项目回退到 `cobc`。执行项目命令前请先保存缓冲区。

`:CobolBuild`、`:CobolRun`、`:CobolTest` 异步执行，并把编译器位置写入 Quickfix 列表（`:cnext`、`:cprev`）。

## 命令

| 命令 | 功能 |
| --- | --- |
| `:CobolGuideToggle` | 开关视觉提示与诊断附着 |
| `:CobolGuideEnable` / `:CobolGuideDisable` | 重新附着或解除提示与诊断 |
| `:CobolToggleComment` | 按源格式切换注释；可指定范围 |
| `:CobolGotoDef` | 跳转到定义 |
| `:CobolGotoCopybook` | 打开 Copybook |
| `:CobolPreview` | 预览段落或 Copybook |
| `:CobolCalcRecord` | 显示记录布局估算 |
| `:CobolStructure` | 报告光标处期望的 `END-*` 关键字 |
| `:CobolFormatCase` | 格式化识别到的保留字 |
| `:CobolLint` | 运行 GnuCOBOL 语法检查 |
| `:CobolQuickfix` | 打开诊断 Quickfix 列表 |
| `:CobolDiagnosticsToggle` | 开关自动诊断 |
| `:CobolBuild` / `:CobolRun` / `:CobolTest` | 构建 / 运行 / 测试项目 |

## 配置选项

默认值适用于小型项目。项目级配置示例：

```lua
{
  "iamcheyan/cobol.nvim",
  ft = { "cobol", "cbl", "cob" },
  opts = {
    project_root = vim.fn.expand("~/src/my-cobol-project"),
    copybook_paths = { ".", "./cpy", "./copybooks", "./include" },
    cobc_command = "cobc",
    cobc_extra_args = {},
    source_format = "auto",
    structure_scope = { enable = true, char = "┆", show_branches = true },
    folding = { enable = true, foldtext = "auto" },
    diagnostics = { enable = true, debounce_ms = 600 },
  },
}
```

其他选项包括 `show_hierarchy_hint`、`show_pic_size`、`highlight_levels`、`show_colorcolumn`、`disable_indent_guide`、`diagnostics.on_save`/`on_change`、`diagnostics.warnings`/`dialect`、`completion.enable`；默认值见 `:help cobol-configuration`。源码中声明的 `enabled`、`overflow_col`、`smart_comments` 目前并未按其值控制对应行为，请不要当作开关使用。

## 排查

- **没有标尺或映射**：检查 `:set filetype?`、`:verbose nmap gd` 和 `keymaps`。
- **没有结构标记、面包屑或 `%` 配对**：缺少 Tree-sitter 解析器。安装 C 编译器或用 `./scripts/build_parser.sh` 编译 `cobol.so`。
- **没有大纲**：侧栏来自可选的大纲插件（Aerial 或 Syms），请自行安装配置。
- **没有诊断**：检查 `:echo executable('cobc')` 与 `cobc_command`。
- **找不到 Copybook**：设置 `project_root` 并把目录加入 `copybook_paths`。
- **长度估算异常**：把计算结果当作估算值，用目标编译器核实。

## 开发

在仓库根目录运行测试：

```bash
./scripts/test.sh
```

未安装 Aerial 时，其专用测试会跳过；核心测试不依赖 Aerial。

## 许可证

MIT，见 [LICENSE](LICENSE)。
