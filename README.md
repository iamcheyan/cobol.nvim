# cobol.nvim

COBOL editing support for Neovim, with a focus on fixed-format source code and a beginner-friendly workflow.

The plugin helps you read existing COBOL programs, understand their layout, find definitions and copybooks, inspect data records, and catch syntax errors while you work. It does not require a language server.

[简体中文](README.zh-CN.md) · [日本語](README.ja.md)

The complete Chinese learning guide includes a COBOL introduction, a reference
for every plugin feature, project setup, and step-by-step exercises:
[README.zh-CN.md](README.zh-CN.md).

![cobol.nvim overview](assets/cobol.nvim-overview.png)

The screenshot shows the main workflow: the Aerial structure outline, fixed-format column guides, COBOL navigation, and a copybook preview in the editor. Aerial is a Neovim plugin that provides a searchable code-structure Outline sidebar.

## Who is it for?

`cobol.nvim` is useful for beginners learning fixed-format COBOL, developers maintaining `.cob`, `.cbl`, or `.cobol` programs, and projects that use copybooks and traditional Division/Section/Paragraph structure.

The bundled Aerial backend recognizes COBOL Divisions, Sections, Paragraphs, file descriptions, and level-01 records. Aerial displays these symbols in a searchable Neovim sidebar; without Aerial, all other navigation features remain available.

## Features

| Area | What it provides | Why it helps |
| --- | --- | --- |
| Fixed-format layout | Guides for columns 7, 8, 12, and 73; overflow highlighting; column jumps | Makes COBOL's source areas visible while you edit |
| Structure and navigation | AST breadcrumbs, nested-block highlighting, `%`, `vaf`/`vif`/`vae`/`vie`/`vap`/`vip`, folding, `gd`, `gf`, and `K` | Navigate COBOL control flow by syntax-tree ranges |
| Data layout | PIC and record-size estimates, including `OCCURS` and `REDEFINES` | Gives beginners a practical view of record storage |
| Completion | COBOL keywords, verbs, clauses, snippets, data names, paragraphs, and copybooks | Reduces typing and helps you discover the vocabulary and structure of a program |
| Context information | Format, source area, breadcrumb, current PIC, and record size | Keeps the most useful COBOL context visible while you move through a file |
| Diagnostics | Asynchronous `cobc -fsyntax-only` checks and Quickfix integration | Finds syntax errors without blocking the editor |
| Editing helpers | Comment toggle, smart Tab, reserved-word case formatting | Reduces repetitive work in fixed-format source |
| Optional outline | Aerial, a Neovim code-structure sidebar, with the COBOL backend | Provides a searchable tree of the program |

## Requirements

- Neovim 0.10 or newer.
- [blink.cmp](https://github.com/saghen/blink.cmp) is optional. Install it to enable the built-in COBOL completion source.
- GnuCOBOL (`cobc`) is optional. Install it to use compiler diagnostics.
- Aerial is optional. It is a Neovim code-structure/Outline sidebar plugin; install it only if you want the outline view.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  build = "bash scripts/build_parser.sh",
  ft = { "cobol", "cbl", "cob" },
  opts = {},
}
```

To add the optional Aerial code-structure sidebar, install Aerial and enable the COBOL backend:

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

The repository name for this plugin belongs in the local lazy.nvim spec, alongside these options.
## Configuration

The defaults are suitable for a small project. A project-specific setup can look like this:

```lua
{
  ft = { "cobol", "cbl", "cob" },
  opts = {
    project_root = vim.fn.expand("~/src/my-cobol-project"),
    copybook_paths = { ".", "./cpy", "./copybooks", "./include" },
    cobc_command = "cobc",
    cobc_extra_args = {},
    source_format = "auto",
    folding = { enable = true, foldtext = "auto" },
    diagnostics = { enable = true, debounce_ms = 600 },
  },
}
```

`project_root` and `copybook_paths` are used by copybook navigation and diagnostics. `source_format` accepts `auto`, `fixed`, or `free`. Without a project root, the plugin uses the current file's directory as a fallback.

## A first workflow

1. Open a COBOL source file and check the column guides. In fixed-format code, column 7 is the indicator area, columns 8–11 are Area A, columns 12–72 are Area B, and column 73 starts the identification area.
2. Use `gd` on a paragraph or data name. Use `gf` on a `COPY` statement and `K` to preview a paragraph or copybook.
3. If the optional Aerial Outline sidebar is installed, press `<leader>cs` to open the structure outline.
4. Place the cursor on a level-01 record or field and press `<leader>cr` to inspect the estimated layout.
5. Save the file or press `<leader>cl` to run a syntax check with GnuCOBOL.
6. Use `za`, `zc`, and `zo` to fold or unfold the current COBOL structure.

## Fixed-format editing

Toggle the guide with `<leader>uc` or `:CobolGuideToggle`. The plugin highlights text beyond column 72, where fixed-format compilers normally ignore source text.

| Key | Destination |
| --- | --- |
| `g7` | Indicator column |
| `g8` | Area A |
| `g12` | Area B |
| `g73` | Identification area |

At the start of a line, Insert-mode `<Tab>` moves input toward Area A or Area B instead of inserting arbitrary indentation. `<leader>c*` and `:CobolToggleComment` toggle comments according to the detected source format: fixed format uses `*` in column 7, while free format uses `*>`. Visual selections are supported.

In fixed-format buffers, Insert-mode `<Tab>` moves through columns 7, 8, and 12; from column 12 onward it inserts a normal `shiftwidth` indent. `<S-Tab>` reverses through these stops without deleting source text. See the [complete Chinese fixed-format guide](README.zh-CN.md#2-固定格式-tab-和智能缩进).

## Navigation and outline

- `gd` / `:CobolGotoDef`: search the source and recursively referenced Copybooks; choose when names are ambiguous.
- `gf` / `:CobolGotoCopybook`: open the Copybook under the cursor, with a choice when paths are ambiguous.
- `K` / `:CobolPreview`: preview the declaration and its source file in a floating window.
- `<C-o>`: return through Neovim's jump list.
- `<leader>cs`: toggle the optional Aerial Outline sidebar.

### Tree-sitter structural navigation

The plugin automatically compiles and installs the parser on startup if a C compiler (`gcc`, `clang`, or `cc`) is available on your system. You can also specify `build = "bash scripts/build_parser.sh"` in your plugin manager, or build it manually:

```sh
./scripts/build_parser.sh
```

Or compile manually using `gcc`:

```sh
gcc -O2 -shared -fPIC \
  -I tree-sitter-cobol/src -I tree-sitter-cobol/src/tree_sitter \
  -o ~/.local/share/nvim/site/parser/cobol.so \
  tree-sitter-cobol/src/parser.c tree-sitter-cobol/src/scanner.c
```

With the parser installed:

- **Structure Scope Badges & Connecting Lines**: When the cursor enters a control block, opening keywords (e.g. `IF`, `EVALUATE`, `PERFORM`, `EXEC SQL`) and matching `END-*` keywords are highlighted with **distinct colored background badges and crisp bold white text**. Simultaneously, a **vertical dashed guide line (`┆`)** is drawn down the aligned column between the opening and closing keywords, visually enclosing the entire block so its closure is immediately recognizable. Nested structures cycle through a rainbow depth palette (Level 1 Blue `#204a87`, Level 2 Gold `#8f5902`, Level 3 Red `#a40000`, Level 4 Green `#2e7d32`, Level 5 Purple `#7b1fa2`, Level 6 Cyan `#00838f`). Customization: `structure_scope = { enable = true, char = "┆" }`.
- **AST Breadcrumb**: Tracks the full structural hierarchy (`Division > Section > Paragraph > IF > EVALUATE > WHEN`). The vendored grammar keeps statements, headers and `END-*` tokens as flat siblings, so the chain is rebuilt from the paired structure ranges instead of tree ancestry: a `WHEN` clause and its enclosing `IF`/`EVALUATE` are resolved by range, and a division, section or paragraph contributes only its header line. Exposed through:
  - Winbar: Automatically integrated when `show_breadcrumbs = true` in config. The breadcrumb is clipped from the left when the window is narrow, so the innermost structures stay visible.
  - Statusline: `require("cobol.ast").statusline(bufnr)` returns formatted breadcrumb string.
  - Floating Window: `require("cobol.ast").show_breadcrumb_float()` displays the full chain in an interactive floating popup (`q` or `<Esc>` to dismiss).
- **Waiting Closures Stack**: `:CobolStructure` or `require("cobol.ast").show_waiting_closures_float()` displays blocks awaiting closure at the cursor position, ordered innermost first (e.g. `END-EVALUATE`, `END-IF`, `END-PERFORM`, `END-EXEC`). With `show_waiting_closures = true` the same stack is drawn on the right edge of the winbar and follows the cursor.
- **Matching Jump (`%`)**: Press `%` to jump bidirectionally between block starts and their corresponding `END-*` keywords across all supported structures (e.g. `IF` <-> `END-IF`, `EVALUATE` <-> `END-EVALUATE`, `PERFORM` <-> `END-PERFORM`, `EXEC SQL` <-> `END-EXEC`, `XML PARSE` <-> `END-XML`, `JSON PARSE` <-> `END-JSON`, `CLASS-ID` <-> `END CLASS`).
- **Tree-sitter Text Objects**:
  - `vaf` / `vif`: Select around / inside `IF ... END-IF`
  - `vae` / `vie`: Select around / inside `EVALUATE ... END-EVALUATE`
  - `vap` / `vip`: Select around / inside `PERFORM ... END-PERFORM`
- **Enhanced Folding (`foldtext`)**: Folds automatically display structure keywords and condition summaries (e.g. `+-- IF STATUS = "A"`, `+-- EVALUATE TXN-TYPE`, `+-- SQL SELECT`, `+-- XML PARSE`) rather than just raw line counts.
- **Hierarchical Outline (Aerial / Syms)**: Real multi-level parent-child tree:
  - Sections (`INPUT-SECTION`)
  - Paragraphs (`VALIDATE-INPUT`)
  - Control structures (`IF WS-AMOUNT > ZERO`, `EVALUATE TXN-TYPE`, `WHEN "D"`, `PERFORM UNTIL EOF`)
  - File operations (`READ CUSTOMER-FILE`, `WRITE REPORT-LINE`, `REWRITE CUSTOMER-REC`, `DELETE ...`, `START ...`)
  - Searches (`SEARCH CUSTOMER-TABLE`)
  - Subroutine calls (`CALL CUSM001`, unquoted)
  - Embedded SQL statements (`SQL SELECT`, `SQL INSERT`, `SQL UPDATE`, `SQL DELETE`, `SQL CURSOR`, `SQL FETCH`, `SQL OPEN`, `SQL CLOSE`, `SQL COMMIT`, `SQL ROLLBACK`)

### Coverage & Grammar Details

The bundled grammar (`tree-sitter-cobol/`, derived from Yutaro Sakamoto's MIT-licensed grammar) provides first-class AST nodes with corpus tests for:
- Standard COBOL 85:
  - `IF ... END-IF`
  - `EVALUATE ... END-EVALUATE`
  - `PERFORM UNTIL / VARYING ... END-PERFORM`
  - `SEARCH / SEARCH ALL ... END-SEARCH`
  - `READ ... END-READ`
  - `WRITE ... END-WRITE`
  - `REWRITE ... END-REWRITE`
  - `DELETE ... END-DELETE`
  - `START ... END-START`
  - `STRING ... END-STRING`
  - `UNSTRING ... END-UNSTRING`
- Dialect & Enterprise Extensions:
  - `XML PARSE ... END-XML`
  - `JSON PARSE ... END-JSON`
  - `EXEC SQL ... END-EXEC`
  - `CLASS-ID ... END CLASS`
  - `METHOD-ID ... END METHOD`
  - `FACTORY ... END FACTORY`
  - `OBJECT ... END OBJECT`

## GnuCOBOL fixed-format project profile

Create `.cobol.json` in the project root:

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

Project paths resolve from the discovered root. The same Copybook paths,
compiler, format, dialect, and extra arguments are used by navigation,
completion, diagnostics, and single-file builds. The profile is optional: when
`.cobol.json` is absent, Neovim defaults are used silently; malformed JSON or
invalid profile fields still produce a warning and fall back to safe defaults.
Without explicit commands,
the plugin recognizes Makefile `build`/`all`, `run`, and `test`/`check`
targets. Command values are argument arrays and run without a shell. A
single-source project without a Makefile falls back to `cobc`; multi-source
projects should define their own build rules. Save the current buffer before
running project commands.

If a Makefile defines build rules but no `run` target, add one or set
`commands.run`; the plugin reports the missing entry point instead of guessing
which program to run.

`:CobolBuild`, `:CobolRun`, and `:CobolTest` run asynchronously. Compiler
locations are placed in Quickfix; use `:cnext` and `:cprev` to move between
entries.

## Completion

When `blink.cmp` is installed, the plugin registers a COBOL completion source automatically for `cobol`, `cbl`, and `cob` buffers. It does not require a COBOL language server.

The source suggests common COBOL verbs and clauses, ready-to-expand snippets such as `IF ... END-IF` and `PERFORM ... END-PERFORM`, names declared in the current buffer, and symbols found in referenced Copybooks. Suggestions are case-insensitive and are most useful after typing a word prefix such as `PER`, `WS-`, or `COPY`.

Completion is an optional convenience: the ruler, navigation, calculator, folding, formatting, and diagnostics continue to work without `blink.cmp`.

## Folding and formatting

Fixed-format buffers use COBOL-aware indentation for common blocks and data
levels. Run `gg=G` to indent the file or `=` over a Visual selection.
Sequence/indicator lines, continuation lines, comments, and nonblank reference
area text at columns 73–80 are preserved.

The plugin provides native folding for Divisions, Sections, Paragraphs, and data records: `za` toggles the current fold, `zc` closes it, and `zo` opens it.

Fold text is a window-local option and several plugins claim it. `folding.foldtext` decides who owns it:

| Value | Behaviour |
| --- | --- |
| `"auto"` (default) | Install the COBOL summary (`+-- IF STATUS = "A"`, `+-- EVALUATE TXN-TYPE`, `+-- PERFORM UNTIL EOF`) unless nvim-ufo manages the buffer, in which case ufo's own fold text -- which already shows the structure keyword plus a line count -- is left in place. |
| `"plugin"` | Always use the COBOL structure summary. |
| `"off"` | Never touch `foldtext` (and restore Neovim's default when this plugin set it). |

`:CobolFormatCase` formats the current line, a Visual selection, or the whole buffer. It changes recognized COBOL reserved words while preserving strings, comments, and user-defined names. It is a conservative case formatter, not a full source reformatter.

## PIC and record calculator

`<leader>cr` or `:CobolCalcRecord` opens a layout table for the current record or field. It estimates sizes for common `DISPLAY`, `COMP`/`BINARY`, `COMP-3`/`PACKED-DECIMAL`, `OCCURS`, and `REDEFINES` declarations.

These values are estimates based on common GnuCOBOL and platform conventions. They are useful for learning and review, but the compiler remains the authority for an application's actual ABI and storage layout.

## Diagnostics

`cobol.nvim` can run:

```text
cobc -fsyntax-only ...
```

The check runs asynchronously after saving, after text changes with a debounce, or when leaving Insert mode. `<leader>cl` or `:CobolLint` runs it immediately, and `<leader>cq` or `:CobolQuickfix` opens the resulting Quickfix list. Use `:CobolDiagnosticsToggle` to enable or disable automatic diagnostics.

Unsaved buffer contents are passed to the compiler through standard input when possible. If `cobc` is not installed, the plugin does not crash; install GnuCOBOL or set `cobc_command` to the correct executable.

## Commands

| Command | Purpose |
| --- | --- |
| `:CobolGuideToggle` | Toggle column guides and the winbar |
| `:CobolGuideEnable` / `:CobolGuideDisable` | Enable or disable the guides |
| `:CobolGotoDef` | Jump to a definition |
| `:CobolGotoCopybook` | Open a copybook |
| `:CobolPreview` | Preview a paragraph or copybook |
| `:CobolCalcRecord` | Show the record layout estimate |
| `:CobolFormatCase` | Format recognized reserved words |
| `:CobolLint` | Run the GnuCOBOL syntax check |
| `:CobolQuickfix` | Open the diagnostics Quickfix list |
| `:CobolDiagnosticsToggle` | Toggle automatic diagnostics |
| `:CobolToggleComment` | Toggle a fixed-format comment |
| `:CobolBuild` / `:CobolRun` / `:CobolTest` | Build, run, or check the project |

## Practice repository

The companion COBOL workshop repository is small and runnable. It is optional, and provides examples for practicing the features described here.

```bash
git clone <companion-repository-url> ~/cobol-practice
cd ~/cobol-practice
make check
nvim INPUTCSV.COB
```

The lessons cover fixed-format source, copybooks, PIC clauses and storage, `REDEFINES`, `OCCURS`, `SEARCH ALL`, and control-break reporting. Read `docs/01` through `docs/07` in order. The final lab maps the examples to the plugin's navigation, calculator, folding, formatting, and diagnostics commands.

## Troubleshooting

- **No column guide:** confirm that `:set filetype?` reports `cobol`.
- **No outline:** the Outline sidebar is provided by the optional Aerial Neovim plugin; install it and add the configuration shown above.
- **No diagnostics:** run `:echo executable('cobc')` and install GnuCOBOL or correct `cobc_command`.
- **Copybook not found:** set `project_root` and include the copybook directories in `copybook_paths`.
- **Unexpected layout size:** treat calculator output as an estimate and verify the declaration with the compiler and platform documentation.

## Development

Run the test suite from the repository root:

```bash
./scripts/test.sh
```

The Aerial-specific test is skipped when Aerial is not installed; the core tests do not require it.

## License

MIT. See [LICENSE](LICENSE).
