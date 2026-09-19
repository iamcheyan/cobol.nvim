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

## P0：先修复正确性和可独立使用性

### Aerial 迁移

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

## 推荐执行顺序

1. 完成 Aerial 迁移后的双路径验证。
2. 修复 PIC calculator 的 `COMP-1` / `COMP-2`，建立测试 fixture。
3. 统一 Copybook 和诊断配置，并补充 `cobc` 降级行为。
4. 增加 parser、calculator、diagnostics 的最小自动化测试。
5. 实现语法折叠。
6. 实现安全的关键字大小写格式化。
7. 最后整理 help 文档、CI 和第一个稳定版本。
