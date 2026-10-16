# Changelog

## Unreleased

- Fix the AST breadcrumb: the bundled grammar keeps statements, headers and
  `END-*` tokens as flat siblings, so the previous tree-ancestry walk printed
  the entire `PROCEDURE DIVISION` body instead of a chain. The chain
  (`Division > Section > Paragraph > IF > EVALUATE > WHEN`) is now rebuilt from
  the paired structure ranges, `WHEN` is resolved by range, and long chains are
  clipped in the winbar instead of being truncated by Neovim.
- Fix `EXEC SQL` statements that are not a bare `SELECT`: `UPDATE ... SET`,
  `DELETE ... WHERE`, `DECLARE ... CURSOR FOR` and SQL qualified names used to
  produce a parse `ERROR` node that swallowed `END-EXEC`, so the block could not
  be paired, jumped to, folded or listed. The bundled grammar now keeps the
  statement body permissive while still terminating at `END-EXEC`, and
  `DECLARE CURSOR` is labelled `SQL CURSOR`.
- Draw the waiting-closures stack on the right edge of the winbar
  (`show_waiting_closures`, default `true`), so outstanding `END-*` keywords are
  visible while editing instead of only through `:CobolStructure`.
- Add `folding.foldtext` (`auto`/`plugin`/`off`) so the COBOL fold summary is no
  longer silently overwritten by nvim-ufo.
- Guard `ast.update` against windows whose cursor does not belong to the COBOL
  buffer (winbar/statusline evaluation), which could throw from a redraw.
- Remove the unused `queries/cobol/structure.scm` query.
- Add `tests/winbar_spec.lua` plus breadcrumb, cursor-guard, foldtext-ownership
  and EXEC SQL pairing regressions to the headless specs.

## 0.1.1

- Warn when Neovim diagnostics are disabled for a COBOL buffer.
- Improve compiler and Copybook configuration handling.

## 0.1.0

- Initial standalone release of `cobol.nvim`.
- Added fixed-format guide, navigation, PIC calculator, diagnostics, folding,
  keyword case formatting, and optional Aerial integration.
- Added headless tests and GitHub Actions validation.
