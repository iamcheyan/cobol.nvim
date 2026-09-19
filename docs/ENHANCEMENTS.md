# COBOL Enhancement Plan

This document records the next enhancements for `cobol.nvim`. The plugin should
remain useful without a COBOL language server and should prefer Neovim-native
interfaces over highly customized keybindings. Optional integrations must not
disable the core editor features.

## Current baseline

The plugin already provides fixed-format guides, fixed-format `gcc` comments,
navigation, Copybook lookup and preview, folding, PIC and record-size
estimates, GnuCOBOL diagnostics, Aerial integration, and `blink.cmp`
completion.

## Prioritized work

### 1. Complete comment integration

Status: partially complete.

- [x] Use COBOL fixed-format comments for `gcc` in COBOL buffers.
- [x] Keep the mapping buffer-local so other filetypes retain Neovim's default.
- [ ] Support Visual-mode `gc` with the same fixed-format behavior.
- [ ] Support the native `gc` operator flow where practical.
- [ ] Recognize fixed-format comments, free-format `*>` comments, and compiler
      continuation lines without changing unrelated text.
- [ ] Skip blank lines, existing comment lines, and Copybook boundaries safely.

### 2. COBOL-aware indentation

Status: planned.

Provide a native `indentexpr` implementation for `IF`/`END-IF`, `EVALUATE`,
`PERFORM`, `READ ... AT END`, `SEARCH`, `EXEC ... END-EXEC`, divisions,
sections, paragraphs, and data levels such as `01`, `05`, and `10`. It should
respect fixed-format Area A and Area B instead of applying generic bracket
indentation.

### 3. More complete diagnostics

Status: planned.

- [ ] Preserve error, warning, and informational severity.
- [ ] Resolve diagnostics reported from Copybooks to the actual Copybook file.
- [ ] Warn about missing Copybooks and duplicate definitions.
- [ ] Support project-specific dialects and compiler arguments.
- [ ] Improve parsing across GnuCOBOL versions and output formats.

### 4. Project build and run workflow

Status: planned.

Detect common project conventions such as `Makefile`, `build.sh`, `src/`,
`copy/`, `cpy/`, and `include/`, then expose optional commands:

```text
:CobolBuild
:CobolRun
:CobolTest
```

The commands should delegate to the project build files when present rather
than inventing a project-specific build system.

### 5. Copybook improvements

Status: partially complete.

- [x] Navigate to Copybooks and preview their contents.
- [x] Include referenced Copybook definitions in completion.
- [ ] Parse `COPY ... REPLACING` substitutions.
- [ ] Cache and invalidate Copybook symbols safely.
- [ ] Show Copybook source in hover and definition results.
- [ ] Report ambiguous or duplicate Copybook paths.
- [ ] Show which files reference a selected Copybook.

### 6. More accurate PIC and storage calculations

Status: partially complete.

Extend the calculator and document compiler/platform assumptions for `PIC X`,
`9`, `S9`, `V`, `P`, `COMP`, `COMP-1`, `COMP-2`, `COMP-3`, `COMP-5`, `BINARY`,
`SYNC`, separate signs, `OCCURS DEPENDING ON`, `REDEFINES`, and `RENAMES`.
The result must remain an estimate unless confirmed by the compiler and target
platform.

### 7. Data-definition assistance

Status: planned.

- [ ] Show the complete parent path for the current data item.
- [ ] Show the owning 01 record, PIC clause, storage type, and size.
- [ ] Show `REDEFINES` and `OCCURS` relationships.
- [ ] Find references to a data name.
- [ ] Provide a carefully scoped data-name rename operation.

### 8. Paragraph and Section navigation

Status: planned.

Add native-style navigation for the next and previous Paragraph or Section,
for example `]m`, `[m`, `]s`, and `[s` when those mappings are explicitly
enabled. Also provide commands such as `:CobolNextParagraph` and
`:CobolListParagraphs` without changing unrelated Vim motions by default.

### 9. SQL and CICS blocks

Status: planned and optional.

Recognize `EXEC SQL ... END-EXEC` and `EXEC CICS ... END-EXEC` blocks for
folding, highlighting, navigation, and optional keyword completion. This must
be modular so ordinary GnuCOBOL users do not need DB2, Oracle, or CICS tools.

### 10. Debugging support

Status: planned.

Investigate an optional DAP workflow for breakpoints, stepping, the call
stack, Working-Storage values, and input/output files. It should use an
existing debugger integration where possible instead of embedding a debugger.

### 11. COBOL status and context information

Status: implemented.

`require("cobol.statusline")` provides a reusable component for lualine,
Heirline, winbar, or `statusline` configurations:

```lua
local cobol_status = require("cobol.statusline")

-- lualine-style component
{ cobol_status.component() }

-- Or call it directly from a provider
cobol_status.get()
```

In a COBOL buffer it can show:

- Fixed/free source format
- Fixed-format area under the cursor
- Division, Section, Paragraph, or data breadcrumb
- Current field name and PIC clause
- Current field size
- Enclosing 01 record size

Outside COBOL buffers it returns an empty string. The plugin's COBOL winbar
also includes this context automatically, without changing other filetypes.

### 12. Tree-sitter support

Status: investigate later.

If a stable COBOL Tree-sitter parser becomes available, use it as an optional
backend for syntax highlighting, folding, text objects, Aerial symbols, and
precise navigation. The handwritten parser must remain the fallback so that
`cobol.nvim` does not require Tree-sitter just to edit COBOL.

## Validation policy

Every completed item should include a focused headless test or a reproducible
manual check using the companion [iamcheyan/cobol](https://github.com/iamcheyan/cobol)
practice repository. Run `./scripts/test.sh` before committing and verify that
optional dependencies are absent as well as installed.
