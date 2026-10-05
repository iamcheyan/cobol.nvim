# Fixed-format COBOL Tab behavior / 固定格式 COBOL 的 Tab 行为

## English

These mappings apply only to fixed-format COBOL buffers (`cobol`, `cbl`, and `cob`). The cursor position is treated as an insertion column: column 1 is the position before the first character; an end-of-line insertion point is one column after the last displayed character.

When the text before the cursor contains only spaces or tabs:

| Key | Insertion column | Result |
| --- | ---: | --- |
| `<Tab>` | 1–6 | Move to column 7 (indicator column) |
| `<Tab>` | 7 | Move to column 8 (Area A) |
| `<Tab>` | 8–11 | Move to column 12 (Area B) |
| `<Tab>` | 12 or later | Insert `shiftwidth` spaces (4 when `shiftwidth` is unset/zero) |
| `<S-Tab>` | 13 or later | Move left by one `shiftwidth`, but not past column 12 |
| `<S-Tab>` | 12 | Move to column 8 |
| `<S-Tab>` | 9–11 | Move to column 8 |
| `<S-Tab>` | 8 | Move to column 7 |
| `<S-Tab>` | 7 or earlier | Remove leading whitespace back to column 1 |

Only leading whitespace before the insertion point is changed. Source text to the right of the cursor is preserved. When the prefix before the cursor contains non-whitespace source text, the fixed-column action declines; `<Tab>` falls through to normal completion/editor behavior and `<S-Tab>` uses Neovim's normal insert-mode unindent behavior. Non-COBOL buffers do not receive these buffer-local mappings. Free-format COBOL buffers are excluded by automatic source-format detection.

## 中文

这些映射只作用于 fixed-format COBOL 缓冲区（`cobol`、`cbl`、`cob`）。位置按“插入点列”计算：第 1 列是首字符前的位置；行尾插入点是最后一个显示字符之后一列。

当光标前只有空格或制表符时：

| 按键 | 插入点列 | 行为 |
| --- | ---: | --- |
| `<Tab>` | 1–6 | 跳到第 7 列（指示区） |
| `<Tab>` | 7 | 跳到第 8 列（Area A） |
| `<Tab>` | 8–11 | 跳到第 12 列（Area B） |
| `<Tab>` | 12 及之后 | 插入 `shiftwidth` 个空格（未设置或为 0 时按 4 个空格） |
| `<S-Tab>` | 13 及之后 | 向左退一个 `shiftwidth`，但不越过第 12 列 |
| `<S-Tab>` | 12 | 回到第 8 列 |
| `<S-Tab>` | 9–11 | 回到第 8 列 |
| `<S-Tab>` | 8 | 回到第 7 列 |
| `<S-Tab>` | 7 或之前 | 删除前导空白，回到第 1 列 |

只会修改插入点之前的前导空白，不会删除光标右侧的源代码。若光标前已有非空白源代码，则不执行定列跳转：`<Tab>` 交回普通补全/编辑器行为，`<S-Tab>` 使用 Neovim 的普通 Insert 模式反缩进。非 COBOL 缓冲区不会安装这些 buffer-local 映射；自动识别为 free-format 的 COBOL 文件也不使用 fixed-format 列停靠。
