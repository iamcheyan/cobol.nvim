# cobol.nvim 智能体修改审计与诊断报告

- **报告日期**：2026-10-16
- **审计目标**：`cobol.nvim`（本地开发路径 `~/development/cobol.nvim`）
- **问题反馈**：“昨天有另外一个智能体改了好多东西，但发现改了也没有效果。想知道他都做了什么，问题现在出在哪里，以及如何彻底改好。”

---

## 目录
1. [执行总结 (Executive Summary)](#1-执行总结-executive-summary)
2. [昨日改动详尽梳理 (What Was Done)](#2-昨日改动详尽梳理-what-was-done)
3. [“改了没有效果”的根本原因诊断 (Root Cause Analysis)](#3-改了没有效果的根本原因诊断-root-cause-analysis)
4. [当前插件工作区状态与遗留技术点](#4-当前插件工作区状态与遗留技术点)
5. [完整修复与落地步骤建议 (Action Plan)](#5-完整修复与落地步骤建议-action-plan)

---

## 1. 执行总结 (Executive Summary)

昨天的智能体针对 `cobol.nvim` 进行了深度的架构扩展，主要目标是实现 **基于 Tree-sitter AST 的语法结构分析、双向闭合跳转 (`%`)、Winbar 面包屑与待闭合提示栈、折叠摘要以及 Aerial 符号大纲**。

该智能体产出了高质量的代码与测试（单测覆盖率极高且全部通过），但**用户在实际 Neovim 中使用时感觉“完全没有效果”**。

经深入排查，导致“没有效果”的**最主要原因并非代码逻辑错误，而是插件加载路径与运行时环境断层**：
1. **Lazy.nvim 运行时路径断层**：用户的 Neovim 配置中，`cobol.nvim` 是按 GitHub 远程仓库引入的，Lazy 实际加载的路径是 `~/.local/share/nvim/lazy/cobol.nvim`，而昨日的所有开发修改均发生在本地开发目录 `~/development/cobol.nvim`。Neovim 根本没有加载本地开发目录中的代码！
2. **工作树遗留大量未提交改动**：昨日智能体在本地开发目录中完成了关键的 AST 面包屑重构、Winbar 裁剪保护与 EXEC SQL 语法修复，但**未提交（Uncommitted/Unstaged）**，导致即使同步远程仓库也无法获取最新修复。
3. **Tree-sitter 动态库编译机制**：扩展语法依赖本地编译生成的 `cobol.so` 共享库，若未编译或路径未命中，AST 功能会静默失效。

---

## 2. 昨日改动详尽梳理 (What Was Done)

昨日（2026-10-15）智能体共提交了 7 个 Commit，并在工作区遗留了关键修改：

### 2.1 Git 提交历史 (7 个 Commits)
- **`4feda13`** - `feat: add Tree-sitter COBOL structure navigation`
  - 新增 `lua/cobol/ast.lua`：利用 Tree-sitter 遍历语法树，解析 COBOL 结构。
  - 新增 `lua/aerial/backends/cobol.lua`：为 `aerial.nvim` 提供 COBOL 符号大纲支持。
  - 新增 `lua/cobol/navigation.lua`：集成双向跳转 `%` 按键映射。
- **`f1e3e91`** - `feat: implement AST structure navigation, folds, breadcrumbs and outline`
  - 新增 `lua/cobol/folding.lua`：支持按 Division / Section / Paragraph 及代码块结构折叠。
  - 在 `lua/cobol/init.lua` 中集成 Winbar 面包屑。
  - 新增回归测试：`tests/folding_spec.lua`、`tests/aerial_spec.lua`。
- **`3e9cecf`** - `feat(ast): restrict AST kinds to verified COBOL85 nodes and test keymaps`
  - 将 AST 支持结构规范化为 COBOL-85 核心 11 个闭合结构，移除无 AST 支持的正则行扫描。
- **`3d974ce`** - `feat(ast): vendor extended Tree-sitter grammar with XML, JSON, SQL, and OO support`
  - **核心重量级改动**：引入并扩充了完整 `tree-sitter-cobol` 语法源（包含 91 万行的 `parser.c`），支持 18 种闭合结构：
    `IF`、`EVALUATE`、`PERFORM`、`SEARCH`、`READ`、`WRITE`、`REWRITE`、`DELETE`、`START`、`STRING`、`UNSTRING`、`XML PARSE`、`JSON PARSE`、`EXEC SQL`、`CLASS-ID`、`METHOD-ID`、`FACTORY`、`OBJECT`。
  - 新增编译脚本 `scripts/build_parser.sh`，将 parser 编译为 Neovim 可识别的 `~/.local/share/nvim/site/parser/cobol.so`。
- **`a0fada5`** - `test: update Tree-sitter comment corpus for AST root`
- **`1a1339e`** - `fix(docs): remove duplicate Tree-sitter help tag`
- **`434c67e`** - `fix(indent): avoid duplicate COBOL open-line indentation`

### 2.2 工作区中遗留的未提交修改 (Unstaged & Untracked)
昨日智能体在发现语法树与界面渲染的边缘 Bug 后进行了修复，但未完成提交：
1. **AST 面包屑扁平化修复 (`lua/cobol/ast.lua`)**：
   - 原语法树中各类语句与 Header 处于同一层级的 flat siblings，原先通过 `node:parent()` 查找层级会导致向上直接穿透到 `procedure_division`，从而在面包屑中打印出整段程序代码。
   - 修复：改为基于行列范围重构链条（`chain()`），精准输出 `Division > Section > Paragraph > IF > EVALUATE > WHEN`。
2. **Winbar 显示与宽度截断保护 (`lua/cobol/init.lua`)**：
   - 之前长面包屑会被 Neovim 单行截断，丢失最内层上下文。
   - 修复：增加 `clip_parts()`，优先保留最内层结构，左侧用 `… > ` 省略；并在右端显示待闭合栈（`⌫ END-IF`）。
3. **EXEC SQL 宽松语法解析 (`tree-sitter-cobol/grammar.js`)**：
   - 解决嵌入式 SQL 中出现 `UPDATE ... SET`、`DELETE`、游标声明或包含点号（`A.B`）时报语法错误并吞噬 `END-EXEC` 的问题。
4. **折叠文本协商 (`lua/cobol/init.lua` & `lua/cobol/folding.lua`)**：
   - 增加 `folding.foldtext = "auto"`，避免覆盖用户已安装的 `nvim-ufo` 折叠文本。
5. **单元测试与文档同步**：
   - 新增 `tests/winbar_spec.lua`。
   - 暂存区标记删除了已废弃的 `queries/cobol/structure.scm`。
   - 更新了 `README.md`、`README.zh-CN.md`、`CHANGELOG.md` 与 `doc/cobol.nvim.txt`。

---

## 3. “改了没有效果”的根本原因诊断 (Root Cause Analysis)

### 诊断 1：Lazy.nvim 加载的是远程克隆，不是本地开发分支（最核心原因）
- **现象**：在 `~/development/cobol.nvim` 做了大量修改，甚至运行 `bash scripts/test.sh` 全部通过，但在日常 Neovim 打开 `.cbl` 文件没有任何变化。
- **排查取证**：
  在 Neovim 中检查运行时加载路径：
  ```lua
  :lua print(vim.inspect(vim.api.nvim_get_runtime_file("lua/cobol/ast.lua", true)))
  -- 输出：{ "~/.local/share/nvim/lazy/cobol.nvim/lua/cobol/ast.lua" }
  ```
  检查该目录的 git 状态：
  ```bash
  cd ~/.local/share/nvim/lazy/cobol.nvim
  git status
  # 输出：HEAD detached from 1a1339e
  ```
  Lazy.nvim 实际运行的代码停留在昨日早期的 `1a1339e` 版本，根本没有加载本地 `~/development/cobol.nvim` 中的任何修改！

### 诊断 2：工作区代码未提交与未推送
- 昨日智能体虽然在 `~/development/cobol.nvim` 修复了面包屑倒灌、SQL 解析、Winbar 裁剪等关键 Bug，但全部停留在工作区未提交。即使在 Neovim 里执行 `:Lazy update`，远程也拉不到这些改动。

### 诊断 3：Tree-sitter 动态库兼容性与依赖
- `cobol.nvim` 的 AST 高亮、配对与 Winbar 严重依赖 `cobol.so`。
- 如果用户未手动执行 `bash scripts/build_parser.sh`，或者如果在不支持 C 编译器的机器上，Neovim 无法加载 `cobol` 语法树，`M.parser()` 直接返回 `nil`，导致所有 AST 增强特性静默降级（外观没有任何反应）。

---

## 4. 当前插件工作区状态与遗留技术点

经过全面检验，当前 `~/development/cobol.nvim` 本地代码质量优秀：
- **测试通过率**：运行 `bash scripts/test.sh`，包含 `ast_spec`、`folding_spec`、`winbar_spec`、`indent_spec`、`navigation_workspace_spec` 等全部 17 个测试套件，**100% 通过（0 failed, 0 skipped）**。
- **Tree-sitter 编译**：执行 `bash scripts/build_parser.sh` 能够顺利编译生成 14MB 的 `~/.local/share/nvim/site/parser/cobol.so`。

---

## 5. 完整修复与落地步骤建议 (Action Plan)

为了让所有修改在用户的 Neovim 中即刻生效，并保证代码库干净可靠，建议按以下三步执行：

### 第一步：提交本地修改至 `cobol.nvim`
将目前未暂存的语法树改进、AST 面包屑修复、Winbar 保护与测试用例进行规范提交并推送：
```bash
cd ~/development/cobol.nvim
git add queries/cobol/structure.scm   # 确认删除废弃查询
git add lua/ tests/ tree-sitter-cobol/ CHANGELOG.md README.md README.zh-CN.md doc/ docs/
git commit -m "feat(ast): complete breadcrumb chain, winbar clipping, SQL parsing, and regression specs"
git push origin main
```

### 第二步：打通 Neovim 与本地开发目录的联动
根据 Neovim 配置规范（`AGENTS.md` 要求公共配置保持干净，不硬编码个人开发路径）：
- **方案 A（推荐，即时生效）：在 `~/.config/nvim-local.lua` 中声明本地插件覆盖**
  `nvim/lua/config/lazy.lua` 会自动读取 `~/.config/nvim-local.lua`。在其中配置：
  ```lua
  return {
    dev = {
      path = "~/development",
      patterns = { "cobol.nvim" },
      fallback = true,
    },
  }
  ```
  或者直接在本地开发配置中指定 `cobol.nvim` 的 `dir` 属性。
- **方案 B（软链接快速生效）：**
  将 `~/.local/share/nvim/lazy/cobol.nvim` 软链接至 `~/development/cobol.nvim`，让任何本地修改即刻映射到编辑器中。

### 第三步：验证实际效果
打开任意 COBOL 文件（如 `tree-sitter-cobol/sample/a.cbl` 或项目代码），验证：
1. 顶部 Winbar 是否正确显示 `Division > Section > Paragraph` 面包屑；
2. 光标在 `IF` / `EVALUATE` / `PERFORM` / `EXEC SQL` 上时，按 `%` 能否在开始与 `END-*` 之间精准跳转；
3. 光标处于深层代码块时，Winbar 右侧是否正确显示待闭合栈（如 `⌫ END-IF`）；
4. `:AerialToggle`（或 `<leader>cs`）能否正常展开 COBOL 代码符号树。
