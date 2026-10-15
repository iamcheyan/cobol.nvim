# tree-sitter-cobol (Extended)

COBOL grammar for [tree-sitter](https://github.com/tree-sitter/tree-sitter).

This is an extended, vendored grammar based on [yutaro-sakamoto/tree-sitter-cobol](https://github.com/yutaro-sakamoto/tree-sitter-cobol) (MIT License, Copyright (c) 2026 Yutaro Sakamoto).

## Dialect Extensions

In addition to standard COBOL 85 control blocks, this grammar provides first-class AST rules and corpus test suites for:
- **XML Parsing**: `XML PARSE ... END-XML` (`xml_parse_statement`, `END_XML`)
- **JSON Parsing**: `JSON PARSE ... END-JSON` / `JSON GENERATE ... END-JSON` (`json_parse_statement`, `END_JSON`)
- **Embedded SQL**: `EXEC SQL ... END-EXEC` (`exec_sql_statement`, `END_EXEC`) with SQL verb recognition (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CURSOR`, `FETCH`, `OPEN`, `CLOSE`, `COMMIT`, `ROLLBACK`)
- **Object-Oriented COBOL**:
  - `CLASS-ID. ... END CLASS` (`class_id_header`, `END_CLASS`)
  - `METHOD-ID. ... END METHOD` (`method_id_header`, `END_METHOD`)
  - `FACTORY. ... END FACTORY` (`factory_header`, `END_FACTORY`)
  - `OBJECT. ... END OBJECT` (`object_header`, `END_OBJECT`)

## Reproducible Build

Compile the grammar to a Neovim-compatible parser shared library:

```bash
./scripts/build_parser.sh
```

Or using tree-sitter CLI:

```bash
tree-sitter generate
tree-sitter test
```
