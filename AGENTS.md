# AGENTS.md - cobol.nvim 插件开发与智能体协作指南

本文档专为参与 `cobol.nvim` 插件研发的 AI Agent 与维护者编写。会话启动或接手任务时，必须严格遵守以下研发规范与多端协作流程。

---

## 1. 核心工作流与发布原则（重要：禁止篡改本地配置）

### 1.1 严禁将用户 Neovim 配置指向本地路径
- **禁止操作**：严禁在用户的 Neovim 插件配置（如 `~/.config/nvim/lua/plugins/cobol.lua`）中添加 `dir = "~/development/cobol.nvim"` 或使用本地路径劫持插件！
- **原因**：用户的 Neovim 必须始终通过标准的包管理器声明（`iamcheyan/cobol.nvim`）管理插件。

### 1.2 标准研发与更新闭环
正确的开发、测试与更新流程如下：
1. **本地开发与测试**：
   - 在本地克隆的开发工作区（本仓库根目录）下进行代码编写与修改。
   - 使用插件内置的 headless 测试套件验证逻辑，运行：
     ```bash
     bash scripts/test.sh
     ```
   - 确保所有单元测试（`*_spec.lua`）100% 绿色通过。
2. **提交与推送**：
   - 编写清晰规范的 Git Commit 消息。
   - 将变更推送到远程 GitHub 仓库：
     ```bash
     git push origin main
     ```
3. **用户端拉取更新**：
   - 任务完成后通知用户。
   - 由用户在 Neovim 内执行 `:Lazy update cobol.nvim`（或在 `:Lazy` 界面按 `U` 更新），拉取最新的远程代码进行真实体验与验收。

---

## 2. 编辑区设计原则：保持源码绝对纯粹，零虚拟文本污染

- **核心准则**：**绝不对文档编辑区（Buffer 源码内部）注入伪造内容或虚拟装饰行**。
- **痛点分析**：若像传统大型机终端一样在源码顶部插入 `=COLS>` 或 `Top of Data` 等虚拟行，极易产生视觉混乱，导致开发者分不清哪些是文档本身的真实代码，哪些是插件插入的虚拟装饰。
- **UI 呈现规范**：
  1. **竖线参考**：仅保留 7/8/12/73 列的无背景字符细线（`│`），自动避让文字，空行贯穿全屏，零文本污染。
  2. **复杂查看器使用独立浮窗**：例如十六进制 / EBCDIC / COMP-3 视图（`:CobolHex`），必须使用独立的 Float Window 浮动窗口展示，按 `q` 或 `<Esc>` 随手关闭，绝不占用编辑区正文。
  3. **行序号受控修改**：`:CobolRenum` 与 `:CobolUnnum` 仅在用户显式触发时对 1-6 列执行确定性操作，并保留第 7 列指示符。
  4. **输入透明处理**：`:CobolCapsToggle` 在 Insert 模式输入流中自动大写转换，保护字符串与第 7 列注释，不产生多余视图装饰。

---

## 3. 架构模块划分

```text
lua/cobol/
├── init.lua          # 插件入口、配置管理、高亮初始化、Winbar面包屑、事件绑定
├── ast.lua           # Tree-sitter AST 解析、面包屑链与待闭合块提取
├── calculator.lua    # PIC 字节数计算、01 Record 内存排布报表 (:CobolCalcRecord, <leader>cr)
├── navigation.lua    # 标识符定义跳转 (gd)、悬浮预览 (K)、Copybook 查找
├── sequence.lua      # 1-6 列行号智能重排 (:CobolRenum) 与清除 (:CobolUnnum)
├── hex.lua           # EBCDIC 转换、ISPF 垂直 Nibble 视图与 COMP-3 解码 (:CobolHex, <leader>ch)
├── caps.lua          # 智能大写输入模式 (:CobolCapsToggle, <leader>cc)
├── diagnostics.lua   # GnuCOBOL (cobc) 异步飞检与语法诊断
├── folding.lua       # Division / Section / Paragraph 智能折叠
├── format.lua        # 关键字大小写格式化
├── indent.lua        # COBOL 智能缩进
└── commands.lua      # 编译与构建命令扩展
```

---

## 4. 关键快捷键约定

| 快捷键 | 命令 / 功能 | 说明 |
|---|---|---|
| `<leader>uc` | `:CobolGuideToggle` | 开关 7/8/12/73 列垂直细线标尺 |
| `<leader>cr` | `:CobolCalcRecord` | 查看当前 01 Record 字段内存偏移排布报表（别名 `<leader>cl`） |
| `<leader>ch` | `:CobolHex` | 打开 EBCDIC / Nibble / COMP-3 独立浮窗查看器 |
| `<leader>cc` | `:CobolCapsToggle` | 切换 ISPF Smart CAPS 智能大写输入模式 |
| `g7` / `g8` / `g12` / `g73` | 跳转列号 | 快速定位到指示符区、Area A、Area B、识别区 |
| `<leader>c*` / `gc` | `:CobolToggleComment` | 切换第 7 列注释符（`*`） |
