# COBOL 标尺与光标十字重合

## 原因

标尺由 decoration provider 的 ephemeral virt_text 绘制。默认高亮模式 replace 会覆盖底层 CursorColumn/CursorLine，哪怕标尺自身没有背景颜色。单独改变光标列颜色或只添加交点标记，无法修复整列被覆盖的问题。

## 修复

所有标尺虚拟文字统一设置 hl_mode = "combine"，保留主题提供的光标列和行背景。源码非空处继续不绘制标尺，不替换源码字符；移除只在光标所在行绘制的临时交点方案。

## 验证

使用 pynvim 启动独立 Neovim 并附加 ext_linegrid UI，读取真实 grid_line 和 hl_attr_define。修复前，第 7 列标尺单元没有 CursorColumn 背景；修复后，光标上下的单元保留该背景。覆盖第 7、8、12、73 列，包括有源码字符的列。测试不访问或操作用户正在使用的编辑器。

运行（需要 pynvim）：

```sh
for col in 7 8 12 73; do RULER_COL=$col python3 tests/ruler_cursor_ui_spec.py; done
```

颜色由当前主题的 CursorColumn/CursorLine 决定，插件不额外硬编码光标颜色。已运行的 Neovim 需要重新加载插件或重启才能使用新 provider。
