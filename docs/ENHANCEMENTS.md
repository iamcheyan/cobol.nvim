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

## Product scenario: intensive GnuCOBOL fixed-format development

### User scenario

The primary workflow is maintaining and writing GnuCOBOL programs in fixed
format. The editor should make the source areas explicit, resolve project
Copybooks consistently, run the same compiler settings during diagnostics and
builds, and make it quick to fix errors and repeat the build/test cycle.

For GnuCOBOL fixed format, columns 1–6 are the sequence area, column 7 is the
indicator area, columns 8–72 contain program text, and columns 73–80 are the
reference area. Editing helpers must preserve this layout and must never move
program text into the reference area by accident.

### User-visible goals and acceptance criteria

1. **Project-aware compiler profile** — implemented
   - A project can declare its source format, GnuCOBOL dialect, Copybook search
     directories, and compiler arguments in a small, documented project file.
   - Relative paths resolve from the detected project root.
   - Diagnostics and build commands use the same profile and pass each
     Copybook directory as its own `-I` argument.
   - Invalid or missing project configuration produces a useful message and
     falls back to safe defaults without crashing Neovim.

2. **One build/run/test loop** — implemented
   - `:CobolBuild`, `:CobolRun`, and `:CobolTest` work from any COBOL buffer in
     the project.
   - If the project provides a Makefile or an explicit command in its profile,
     the plugin delegates to that project command instead of guessing how to
     link multiple program units.
   - A single-file GnuCOBOL program has a documented `cobc` fallback.
   - Output is asynchronous, does not block editing, and can be navigated in
     Quickfix with file and line locations where the compiler provides them.

3. **Fixed-format-aware indentation** — implemented and checked against the practice project
   - Indentation recognizes common block pairs such as `IF`/`END-IF`,
     `EVALUATE`/`END-EVALUATE`, `PERFORM`/`END-PERFORM`, `READ`/`END-READ`,
     `SEARCH`/`END-SEARCH`, and `EXEC`/`END-EXEC`.
   - It respects Area A and Area B, sequence/indicator columns, comment lines,
     continuation lines, and existing leading source columns.
   - Indenting a selection must not change text after column 72.

4. **Project-wide Copybook and symbol navigation** — implemented for the reachable Copybook graph
   - Copybook lookup uses the same profile paths as compilation and diagnostics.
   - `COPY ... REPLACING` is parsed sufficiently for navigation and completion
     to find the referenced Copybook without treating the replacement text as
     the file name.
   - Paragraphs and data names can be searched across the current source and
     its Copybooks; ambiguous matches are shown as choices rather than guessed.
   - Cached symbols are invalidated when a source buffer changes, a Copybook changes on disk, or a buffer is written/deleted.

5. **Trustworthy diagnostics** — implemented and checked with real GnuCOBOL Copybook errors
   - Compiler errors, warnings, notes, and informational messages retain their
     severity and source location.
   - Diagnostics from Copybooks point to the actual Copybook buffer when it is
     open and still identify the originating `COPY` line in the main file.
   - Compiler output formats that omit a column, use a relative path, or report
     source lines expanded from a Copybook are handled without invalid ranges.
   - A clean subsequent compile clears diagnostics from Copybook buffers used
     by the previous compile.

### Delivery order

1. Project profile and shared compiler argument construction.
2. Asynchronous build/run/test commands and Quickfix integration.
3. Fixed-format-aware indentation and safe range formatting.
4. Copybook parsing, project-wide symbol search, references, and ambiguity
   handling.
5. Diagnostic severity/location improvements and cache invalidation.

Every item in this scenario has a focused headless test, a manual check in the
companion practice project, and updated usage instructions. The installed and
absent optional-dependency paths were both checked; missing Aerial is reported
as a skip rather than disabling the rest of the plugin.

## Separate plugin backlog

The following ideas predate the intensive fixed-format workflow above. They
are independent follow-up work and are not acceptance criteria for that
completed scenario.

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

Status: implemented for common fixed-format blocks and data levels. The
practice-project check indented INPUTCSV.COB, kept every nonblank column 73+
tail unchanged, and passed the project's compiler syntax checks.

The native `indentexpr` handles `IF`/`END-IF`, `EVALUATE`, `PERFORM`,
`READ ... AT END`, `SEARCH`, `EXEC ... END-EXEC`, divisions, sections,
paragraphs, and data levels such as `01`, `05`, and `10`. It preserves
sequence and indicator areas, continuation lines, comments, and nonblank text
in columns 73–80.

### 3. More complete diagnostics

Status: implemented for GnuCOBOL plain diagnostics, project profiles, relative
and basename-only Copybook paths, actual open Copybook buffers, and source
COPY-line annotations. Compiler versions with output formats outside these
recognized forms may still need parser updates.

- [x] Preserve error, warning, and informational severity.
- [x] Resolve diagnostics reported from Copybooks to the actual Copybook file.
- [ ] Warn about missing Copybooks and duplicate definitions.
- [x] Support project-specific dialects and compiler arguments.
- [x] Parse GnuCOBOL plain diagnostics with and without columns, relative paths, and Copybook-expanded source references.

### 4. Project build and run workflow

Status: implemented with explicit .cobol.json command arrays, Makefile target
detection, asynchronous output, Quickfix diagnostics, and a single-source
cobc fallback.

Use `.cobol.json` profiles and Makefile targets, then expose:

```text
:CobolBuild
:CobolRun
:CobolTest
```

The commands delegate to project rules when available and use the documented
single-source compiler fallback otherwise.

### 5. Copybook improvements

Status: recursive symbol search, duplicate declaration choices, ambiguous
Copybook choices, file-aware hover, profile-based lookup, and signature-based
cache refresh are implemented. References from arbitrary non-COBOL files and
compiler-expanded rename operations remain future work.

- [x] Navigate to Copybooks and preview their contents.
- [x] Include referenced Copybook definitions in completion.
- [x] Parse the Copybook name from `COPY ... REPLACING` without consuming replacement text.
- [x] Cache and refresh Copybook symbol indexes when buffers or files change.
- [x] Show Copybook source in hover and definition results.
- [x] Present ambiguous definitions and Copybook paths as choices.
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
