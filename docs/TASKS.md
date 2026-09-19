# cobol.nvim 任务清单

这份清单记录从个人配置插件走向可独立发布 GitHub 插件时的剩余工作。
状态以实际源码和验证结果为准，不只以 README 的功能描述为准。

## 当前状态

- [x] Phase 1：固定格式标尺、Winbar、列跳转、智能注释和智能 Tab
- [x] Phase 2.1：面包屑、数据层级提示、可选 Aerial backend
- [x] Phase 2.2：`gd`、`gf`、`K` 和 Copybook 搜索
- [x] Phase 3：PIC 基础计算和 `01` 记录布局
- [x] Phase 4：GnuCOBOL 异步诊断、Quickfix 和 Copybook 诊断关联
- [x] Phase 5：语法折叠和关键字格式化
- [x] Phase 6：COBOL 关键字、代码片段、数据名和 Copybook 补全
- [x] Phase 7：COBOL 状态栏/Winbar 上下文信息

## P0：先修复正确性和可独立使用性

### Aerial 迁移

Aerial 是 Neovim 的代码结构大纲（Outline）侧边栏插件；本项目提供可选的
COBOL backend，让它能够显示 Division、Section、Paragraph 和数据记录。

- [x] 将 Aerial backend 移入 `lua/aerial/backends/cobol.lua`
- [x] 从公开 `dotfiles` 删除 COBOL 专用 backend
- [x] 将 Aerial 配置改为可选集成
- [x] 更新独立安装文档
- [x] 在没有 Aerial 时验证插件仍可正常加载
- [x] 在安装 Aerial 时验证 backend 模块、`cobol/cbl/cob` 文件类型和 lazy.nvim 配置合并
- [x] 在兼容的 Aerial/Neovim 版本中验证 `<leader>cs`、跳转和刷新

### PIC 计算器正确性

- [x] 修复 `COMP-1` / `COMP-2` 被通用 `COMP` 分支提前匹配的问题
- [x] 增加 `USAGE IS`、`SIGN IS SEPARATE` 等常见写法测试
- [x] 验证 `COMP-3`、`BINARY`、`OCCURS`、`REDEFINES` 的边界案例
- [x] 明确平台/编译器 ABI 差异，避免把估算结果描述成绝对布局

### 配置一致性

- [x] 统一导航模块和诊断模块的 Copybook 搜索路径配置
- [x] 支持用户配置项目根目录、Copybook 目录和额外 `cobc` 参数
- [x] 检查全局关闭 `vim.diagnostic` 时，插件是否仍提供明确提示
- [x] 为不存在 `cobc`、不可读 Copybook 和无效 buffer 提供稳定降级行为

## P1：完成 Phase 5

### 补全

- [x] 提供常用 COBOL 动词、子句、级别号和内置函数候选项
- [x] 提供 `IF`、`EVALUATE`、`PERFORM`、`READ`、`WRITE` 等结构化代码片段
- [x] 从当前缓冲区收集字段、条件名、段落、Section 和 Copybook 名称
- [x] 扫描当前文件引用的 Copybook，并将其中的定义加入候选项
- [x] 通过可选的 blink.cmp source 自动接入 `cobol`、`cbl`、`cob` 文件类型
- [x] 在没有 blink.cmp 时保持其他插件功能可用

### 语法折叠

- [x] 实现 Division 级折叠
- [x] 实现 Section 级折叠
- [x] 实现 Paragraph 级折叠
- [x] 实现 DATA DIVISION 记录组折叠
- [x] 不破坏固定格式列和 Aerial 的折叠联动

### 关键字格式化

- [x] 实现 `:CobolFormatCase`
- [x] 支持当前行、Visual selection 和全文件范围
- [x] 只修改 COBOL 保留字，不修改变量名、字符串、注释和 Copybook 内容
- [x] 处理 `END-IF`、`END-PERFORM` 等带连字符关键字

### 状态栏与上下文

- [x] 提供可供 lualine、Heirline 和 winbar 使用的 `cobol.statusline` 组件
- [x] 显示 Fixed/Free 格式和当前固定格式区域
- [x] 显示 Division、Section、Paragraph 或数据层级面包屑
- [x] 显示当前字段、PIC 定义、字段大小和所属 01 记录大小
- [x] 在插件自己的 COBOL Winbar 中自动显示上下文
- [x] 在非 COBOL 文件中返回空内容，不影响其他文件类型

## 后续增强总清单

完整规格、优先级和验证要求见 [ENHANCEMENTS.md](ENHANCEMENTS.md)。当前主要方向：

- 完善 Visual `gc` 和原生注释操作符
- COBOL-aware 原生缩进
- 更完整的 GnuCOBOL 诊断与 Copybook 解析
- 工程构建、运行和测试命令
- 数据定义引用和重命名辅助
- Paragraph/Section 原生风格导航
- 可选 SQL/CICS 支持
- 可选 DAP 调试支持
- 稳定后再评估 Tree-sitter backend

## P1：解析器和诊断增强

- [x] 增加更严格的固定格式/自由格式区分
- [x] 改善注释、续行、行内注释和序号区处理
- [x] 处理 `COPY ... REPLACING`
- [x] 处理 `OCCURS ... DEPENDING ON`
- [x] 改善同名 Paragraph、Section 和 Data item 的解析策略
- [x] 适配不同 GnuCOBOL 版本的诊断输出
- [x] 验证未保存 buffer、Copybook 和路径含空格的场景
- [x] 防止快速编辑时旧诊断结果覆盖新 buffer 内容

## P1：测试与工程化

- [x] 添加最小 COBOL fixture：固定格式、自由格式、Data Division、Copybook
- [x] 为 PIC calculator 增加 Lua 单元测试
- [x] 为 Aerial parser 增加结构树快照或断言测试
- [x] 为诊断输出解析增加多种 `cobc` 输出样本测试
- [x] 增加无 Neovim UI 的 headless smoke test
- [x] 添加 GitHub Actions：Lua 语法、测试和文档检查
- [x] 增加版本/变更记录和发布流程

## P2：公共发布质量

- [x] 添加 MIT LICENSE 文件
- [x] 添加 lazy.nvim 安装示例
- [x] 说明最低 Neovim 版本和可选依赖
- [x] 添加 `:help cobol.nvim` 文档
- [x] 删除所有机器专属绝对路径
- [x] 为配置项补充完整文档和默认值表
- [x] 发布第一个带版本号的稳定 tag（`v0.1.0`）

## 发布后练习与回归

1. 使用配套练习仓库的 `INPUTCSV.COB` 验证导航、PIC 计算和实时诊断。
2. 使用 `FIXEDREC.COB` 验证固定格式、`REDEFINES` 和 Copybook 跳转。
3. 使用 `TBLSRCH.COB` 验证 `OCCURS`、Aerial 大纲和数组结构。
4. 使用 `BATCHRPT.COB` 验证 Section、Paragraph、折叠和格式化命令。
5. 插件代码变更后运行 `./scripts/test.sh`，发布前更新 CHANGELOG 和版本 tag。
