# cobol.nvim

面向 Neovim 的 COBOL 编辑支持插件，重点服务于固定格式 COBOL 和初学者的学习流程。

它帮助你阅读程序、理解源码列布局、查找段落和数据定义、打开 Copybook、查看数据记录布局，并在编辑过程中发现语法错误。插件不依赖语言服务器。

[English](README.md) · [日本語](README.ja.md)

![cobol.nvim 功能概览](assets/cobol.nvim-overview.png)

图中展示了插件的主要工作流：Aerial 结构大纲、固定格式列标尺、COBOL 导航，以及编辑器中的 Copybook 预览。

## 适合谁使用？

`cobol.nvim` 适合正在学习固定格式 COBOL 的初学者、维护 `.cob`、`.cbl` 或 `.cobol` 程序的开发者，以及使用 Copybook 和 Division、Section、Paragraph 结构的项目。

核心功能不依赖 Aerial。Aerial 是可选依赖，只用于提供侧边栏大纲。

## 功能概览

| 方向 | 提供的功能 | 对用户的帮助 |
| --- | --- | --- |
| 固定格式布局 | 第 7、8、12、73 列标尺、越界高亮、列跳转 | 直观看到 COBOL 各个源码区域 |
| 结构与导航 | Winbar 面包屑、折叠、`gd`、`gf`、`K` | 快速浏览 Division、段落、字段和 Copybook |
| 数据布局 | PIC 和记录大小估算，支持 `OCCURS`、`REDEFINES` | 帮助理解记录在内存中的组织方式 |
| 诊断 | 异步执行 `cobc -fsyntax-only`，集成 Quickfix | 编辑时发现语法错误，不阻塞界面 |
| 编辑辅助 | 注释切换、智能 Tab、保留字大小写格式化 | 减少固定格式代码中的重复操作 |
| 可选大纲 | Aerial COBOL backend | 提供可搜索的程序结构树 |

## 环境要求

- Neovim 0.10 或更高版本；
- GnuCOBOL（`cobc`）是可选的，安装后才能使用编译器诊断；
- Aerial 是可选的，只在需要侧边栏大纲时安装。

## 安装

使用 [lazy.nvim](https://github.com/folke/lazy.nvim)：

```lua
{
  "iamcheyan/cobol.nvim",
  ft = { "cobol", "cbl", "cob" },
  opts = {},
}
```

启用可选的 Aerial backend：

```lua
{
  "stevearc/aerial.nvim",
  optional = true,
  opts = function(_, opts)
    opts.backends = vim.tbl_deep_extend("force", opts.backends or {}, {
      cobol = { "cobol" },
    })
  end,
}
```

插件不会自动安装 `cobc`，请单独安装 GnuCOBOL。

## 配置

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
    folding = { enable = true },
    diagnostics = { enable = true, debounce_ms = 600 },
  },
}
```

`project_root` 和 `copybook_paths` 用于 Copybook 导航和诊断。`source_format` 可以设置为 `auto`、`fixed` 或 `free`。没有设置项目根目录时，会使用当前文件目录。

## 第一次使用建议

1. 打开 COBOL 源文件并观察列标尺。固定格式中，第 7 列是指示区，第 8–11 列是 Area A，第 12–72 列是 Area B，第 73 列开始是标识区。
2. 在段落名或数据名上按 `gd`；在 `COPY` 语句上按 `gf`，按 `K` 预览段落或 Copybook。
3. 安装 Aerial 后按 `<leader>cs` 打开结构大纲。
4. 将光标放在 01 级记录或字段上，按 `<leader>cr` 查看记录布局估算。
5. 保存文件，或按 `<leader>cl` 使用 GnuCOBOL 执行语法检查。
6. 使用 `za`、`zc`、`zo` 折叠或展开当前结构。

## 固定格式、导航与折叠

使用 `<leader>uc` 或 `:CobolGuideToggle` 切换列标尺。第 72 列之后的文本会被高亮，因为固定格式编译器通常会忽略它。

| 快捷键 | 作用 |
| --- | --- |
| `g7` / `g8` / `g12` / `g73` | 跳到指示列、Area A、Area B、标识区 |
| `gd` / `:CobolGotoDef` | 跳转到段落、数据定义或 Copybook |
| `gf` / `:CobolGotoCopybook` | 打开光标所在的 Copybook |
| `K` / `:CobolPreview` | 浮动窗口预览段落或 Copybook |
| `<C-o>` | 通过 Neovim 跳转列表返回 |
| `<leader>cs` | 切换可选的 Aerial 大纲 |
| `za` / `zc` / `zo` | 切换、关闭、打开当前折叠 |

插件自带的 Aerial backend 可以识别 Division、Section、Paragraph、文件描述和 01 级记录。不安装 Aerial 时，其他导航功能仍然可用。

在行首或前导空白处，Insert 模式的 `<Tab>` 会自动靠近 Area A 或 Area B。`<leader>c*` 和 `:CobolToggleComment` 会在第 7 列添加或移除固定格式注释符，也支持 Visual 选区。

## 格式化与 PIC 计算器

`:CobolFormatCase` 可以格式化当前行、Visual 选区或整个缓冲区。它只修改识别出的 COBOL 保留字，会保留字符串、注释和用户自定义名称。

`<leader>cr` 或 `:CobolCalcRecord` 会打开记录布局表，估算 `DISPLAY`、`COMP`/`BINARY`、`COMP-3`/`PACKED-DECIMAL`、`OCCURS` 和 `REDEFINES`。这些数值基于常见约定，只适合学习和检查；实际 ABI 和存储布局应以编译器和平台文档为准。

## 诊断

插件可以异步执行：

```text
cobc -fsyntax-only ...
```

保存文件、文本修改后的防抖时间到达，或离开 Insert 模式时会检查。`<leader>cl` / `:CobolLint` 立即检查，`<leader>cq` / `:CobolQuickfix` 打开 Quickfix，`:CobolDiagnosticsToggle` 切换自动诊断。

如果没有安装 `cobc`，插件不会崩溃。请安装 GnuCOBOL，或将 `cobc_command` 设置为正确的可执行文件。

## 命令

| 命令 | 作用 |
| --- | --- |
| `:CobolGuideToggle` / `:CobolGuideEnable` / `:CobolGuideDisable` | 切换、开启或关闭列标尺和 Winbar |
| `:CobolGotoDef` / `:CobolGotoCopybook` / `:CobolPreview` | 定义跳转、打开 Copybook、预览内容 |
| `:CobolCalcRecord` | 显示记录布局估算 |
| `:CobolFormatCase` | 格式化识别出的保留字 |
| `:CobolLint` / `:CobolQuickfix` | 执行诊断、打开 Quickfix |
| `:CobolDiagnosticsToggle` | 切换自动诊断 |
| `:CobolToggleComment` | 切换固定格式注释 |

## 配套练习仓库

[iamcheyan/cobol](https://github.com/iamcheyan/cobol) 是一个小型、可运行的 COBOL 练习项目。它不是插件依赖，但提供了练习这里所有功能的示例。

```bash
git clone https://github.com/iamcheyan/cobol.git ~/cobol-practice
cd ~/cobol-practice
make check
nvim INPUTCSV.COB
```

课程覆盖固定格式源码、Copybook、PIC 与存储、`REDEFINES`、`OCCURS`、`SEARCH ALL` 和控制中断报表。建议按 `docs/01` 到 `docs/07` 顺序阅读；最后一课会把示例映射到插件的导航、计算器、折叠、格式化和诊断命令。

## 常见问题

- **没有列标尺：** 检查 `:set filetype?` 是否显示 `cobol`。
- **没有大纲：** Aerial 是可选依赖，请安装并加入上面的配置。
- **没有编译器诊断：** 运行 `:echo executable('cobc')`，安装 GnuCOBOL 或修正 `cobc_command`。
- **找不到 Copybook：** 设置 `project_root`，并将目录加入 `copybook_paths`。
- **布局大小不同：** 计算器结果只是估算值，请用编译器和平台文档确认。

## 开发与许可证

```bash
./scripts/test.sh
```

未安装 Aerial 时，Aerial 专项测试会跳过；其他核心测试不依赖 Aerial。MIT，见 [LICENSE](LICENSE)。
