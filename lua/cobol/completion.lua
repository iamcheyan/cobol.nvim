-- COBOL completion data and source-symbol collection.
-- This module is intentionally independent of a completion UI so it can be
-- tested directly and used by blink.cmp (or another completion engine).

local M = {}

local keyword_groups = {
  { "ACCEPT", "Input" },
  { "ADD", "Arithmetic" },
  { "ALTER", "Procedure" },
  { "CALL", "Procedure" },
  { "CANCEL", "Program" },
  { "CLOSE", "File I/O" },
  { "COMPUTE", "Arithmetic" },
  { "CONTINUE", "Procedure" },
  { "COPY", "Source" },
  { "DELETE", "File I/O" },
  { "DISPLAY", "Output" },
  { "DIVIDE", "Arithmetic" },
  { "ELSE", "Conditional" },
  { "END-ACCEPT", "Scope terminator" },
  { "END-ADD", "Scope terminator" },
  { "END-CALL", "Scope terminator" },
  { "END-COMPUTE", "Scope terminator" },
  { "END-DELETE", "Scope terminator" },
  { "END-DIVIDE", "Scope terminator" },
  { "END-EVALUATE", "Scope terminator" },
  { "END-IF", "Scope terminator" },
  { "END-INVOKE", "Scope terminator" },
  { "END-MULTIPLY", "Scope terminator" },
  { "END-PERFORM", "Scope terminator" },
  { "END-READ", "Scope terminator" },
  { "END-RECEIVE", "Scope terminator" },
  { "END-RETURN", "Scope terminator" },
  { "END-REWRITE", "Scope terminator" },
  { "END-SEARCH", "Scope terminator" },
  { "END-START", "Scope terminator" },
  { "END-STRING", "Scope terminator" },
  { "END-SUBTRACT", "Scope terminator" },
  { "END-UNSTRING", "Scope terminator" },
  { "END-WRITE", "Scope terminator" },
  { "EVALUATE", "Conditional" },
  { "EXEC", "Embedded SQL/CICS" },
  { "EXIT", "Procedure" },
  { "GO", "Procedure" },
  { "GOBACK", "Procedure" },
  { "IF", "Conditional" },
  { "INITIALIZE", "Data" },
  { "INSPECT", "String" },
  { "INVOKE", "Object" },
  { "MOVE", "Data" },
  { "MULTIPLY", "Arithmetic" },
  { "OPEN", "File I/O" },
  { "PERFORM", "Procedure" },
  { "READ", "File I/O" },
  { "RECEIVE", "Communication" },
  { "RETURN", "Procedure" },
  { "REWRITE", "File I/O" },
  { "SEARCH", "Table" },
  { "SET", "Data" },
  { "SORT", "File I/O" },
  { "START", "File I/O" },
  { "STOP", "Procedure" },
  { "STRING", "String" },
  { "SUBTRACT", "Arithmetic" },
  { "UNSTRING", "String" },
  { "USE", "File I/O" },
  { "WHEN", "Conditional" },
  { "WRITE", "File I/O" },
  { "AND", "Operator" },
  { "OR", "Operator" },
  { "NOT", "Operator" },
  { "TRUE", "Condition" },
  { "FALSE", "Condition" },
  { "THAN", "Comparison" },
  { "EQUAL", "Comparison" },
  { "GREATER", "Comparison" },
  { "LESS", "Comparison" },
  { "NUMERIC", "Class test" },
  { "ALPHABETIC", "Class test" },
  { "POSITIVE", "Class test" },
  { "NEGATIVE", "Class test" },
  { "ZERO", "Value" },
  { "SPACES", "Value" },
  { "SPACE", "Value" },
  { "LOW-VALUES", "Value" },
  { "HIGH-VALUES", "Value" },
  { "QUOTES", "Value" },
  { "QUOTE", "Value" },
  { "ALL", "Value" },
  { "BY", "Clause" },
  { "FROM", "Clause" },
  { "INTO", "Clause" },
  { "OF", "Clause" },
  { "ON", "Clause" },
  { "TO", "Clause" },
  { "USING", "Clause" },
  { "GIVING", "Clause" },
  { "RETURNING", "Clause" },
  { "VALUE", "Data clause" },
  { "VALUES", "Data clause" },
  { "PIC", "Data clause" },
  { "PICTURE", "Data clause" },
  { "OCCURS", "Data clause" },
  { "REDEFINES", "Data clause" },
  { "RENAMES", "Data clause" },
  { "REPLACING", "Copybook clause" },
  { "REPLACE", "Source" },
  { "THRU", "Range" },
  { "THROUGH", "Range" },
  { "SECTION", "Structure" },
  { "DIVISION", "Structure" },
  { "PROGRAM-ID", "Identification" },
  { "ENVIRONMENT", "Division" },
  { "DATA", "Division" },
  { "PROCEDURE", "Division" },
  { "IDENTIFICATION", "Division" },
  { "CONFIGURATION", "Section" },
  { "INPUT-OUTPUT", "Section" },
  { "FILE", "Section" },
  { "WORKING-STORAGE", "Section" },
  { "LOCAL-STORAGE", "Section" },
  { "LINKAGE", "Section" },
  { "SCREEN", "Section" },
  { "REPORT", "Section" },
  { "FILE-CONTROL", "Paragraph" },
  { "SELECT", "File clause" },
  { "ASSIGN", "File clause" },
  { "ORGANIZATION", "File clause" },
  { "ACCESS", "File clause" },
  { "MODE", "File clause" },
  { "RECORD", "File clause" },
  { "FD", "File description" },
  { "SD", "Sort description" },
  { "01", "Level number" },
  { "05", "Level number" },
  { "10", "Level number" },
  { "15", "Level number" },
  { "66", "Level number" },
  { "77", "Level number" },
  { "78", "Level number" },
  { "88", "Level number" },
  { "DISPLAY", "Output" },
  { "COMP", "Storage" },
  { "COMP-1", "Storage" },
  { "COMP-2", "Storage" },
  { "COMP-3", "Storage" },
  { "COMP-4", "Storage" },
  { "COMP-5", "Storage" },
  { "BINARY", "Storage" },
  { "PACKED-DECIMAL", "Storage" },
  { "USAGE", "Storage" },
  { "SIGN", "Storage" },
  { "SEPARATE", "Storage" },
  { "JUSTIFIED", "Data clause" },
  { "BLANK", "Data clause" },
  { "FILLER", "Data name" },
  { "INDEXED", "Table clause" },
  { "INDEX", "Table clause" },
  { "KEY", "Table clause" },
  { "ASCENDING", "Table clause" },
  { "DESCENDING", "Table clause" },
  { "TIMES", "Table clause" },
  { "DEPENDING", "Table clause" },
  { "SORTED", "Table clause" },
  { "ASCENDING", "Table clause" },
  { "NEXT", "Search clause" },
  { "AT", "Search clause" },
  { "END-SEARCH", "Scope terminator" },
  { "CONVERTING", "String clause" },
  { "DELIMITED", "String clause" },
  { "TALLYING", "String clause" },
  { "COUNT", "String clause" },
  { "POINTER", "String clause" },
  { "UNSTRING", "String" },
  { "FUNCTION", "Intrinsic function" },
  { "LENGTH", "Intrinsic function" },
  { "TRIM", "Intrinsic function" },
  { "CURRENT-DATE", "Intrinsic function" },
}

local keyword_items = {}
for _, entry in ipairs(keyword_groups) do
  local label, detail = entry[1], entry[2]
  keyword_items[#keyword_items + 1] = {
    label = label,
    kind = "Keyword",
    detail = detail,
    documentation = "COBOL " .. detail:lower() .. ": " .. label,
    sortText = "1-" .. label,
  }
end

local snippet_items = {
  {
    label = "IF ... END-IF",
    kind = "Snippet",
    detail = "Conditional block",
    documentation = "IF condition\n    statements\nEND-IF",
    insertText = "IF ${1:condition}\n    ${0}\nEND-IF",
    sortText = "0-IF",
  },
  {
    label = "EVALUATE ... END-EVALUATE",
    kind = "Snippet",
    detail = "EVALUATE block",
    documentation = "EVALUATE expression\nWHEN value\n    statements\nEND-EVALUATE",
    insertText = "EVALUATE ${1:expression}\nWHEN ${2:value}\n    ${0}\nEND-EVALUATE",
    sortText = "0-EVALUATE",
  },
  {
    label = "PERFORM ... END-PERFORM",
    kind = "Snippet",
    detail = "Inline perform block",
    documentation = "PERFORM UNTIL condition\n    statements\nEND-PERFORM",
    insertText = "PERFORM UNTIL ${1:condition}\n    ${0}\nEND-PERFORM",
    sortText = "0-PERFORM",
  },
  {
    label = "READ ... AT END",
    kind = "Snippet",
    detail = "File read block",
    documentation = "READ file\nAT END\n    statements\nEND-READ",
    insertText = "READ ${1:file}\nAT END\n    ${0}\nEND-READ",
    sortText = "0-READ",
  },
  {
    label = "WRITE ... FROM",
    kind = "Snippet",
    detail = "File write statement",
    documentation = "WRITE record FROM data",
    insertText = "WRITE ${1:record} FROM ${0:data}",
    sortText = "0-WRITE",
  },
  {
    label = "MOVE ... TO",
    kind = "Snippet",
    detail = "Data movement",
    documentation = "MOVE source TO target",
    insertText = "MOVE ${1:source} TO ${0:target}",
    sortText = "0-MOVE",
  },
  {
    label = "DISPLAY ...",
    kind = "Snippet",
    detail = "Display statement",
    documentation = "DISPLAY value",
    insertText = "DISPLAY ${0:value}",
    sortText = "0-DISPLAY",
  },
  {
    label = "PIC X(n)",
    kind = "Snippet",
    detail = "Alphanumeric field",
    documentation = "PIC X(n) stores fixed-length text",
    insertText = "PIC X(${0:length})",
    sortText = "0-PIC-X",
  },
  {
    label = "PIC 9(n)",
    kind = "Snippet",
    detail = "Numeric display field",
    documentation = "PIC 9(n) stores display-format digits",
    insertText = "PIC 9(${0:length})",
    sortText = "0-PIC-9",
  },
  {
    label = "PIC S9(n) COMP-3",
    kind = "Snippet",
    detail = "Packed decimal field",
    documentation = "Signed packed-decimal field",
    insertText = "PIC S9(${1:length}) COMP-3${0}",
    sortText = "0-PIC-COMP-3",
  },
  {
    label = "OCCURS ... TIMES",
    kind = "Snippet",
    detail = "Table declaration",
    documentation = "Repeated data item",
    insertText = "OCCURS ${1:count} TIMES${0}",
    sortText = "0-OCCURS",
  },
  {
    label = "REDEFINES",
    kind = "Snippet",
    detail = "Shared storage declaration",
    documentation = "Overlay an existing data item",
    insertText = "REDEFINES ${0:field}",
    sortText = "0-REDEFINES",
  },
  {
    label = "COPY ...",
    kind = "Snippet",
    detail = "Copybook inclusion",
    documentation = "Insert a copybook during compilation",
    insertText = "COPY \"${0:copybook}.CPY\".",
    sortText = "0-COPY",
  },
}

local level_kinds = { ["01"] = "Record", ["66"] = "Rename", ["77"] = "Field", ["78"] = "Constant", ["88"] = "Condition" }

local function normalize_name(name)
  return name and name:upper() or nil
end

local function add_symbol(symbols, name, kind, detail, line)
  name = normalize_name(name)
  if not name or name == "FILLER" then return end
  symbols[name] = symbols[name] or {
    label = name,
    kind = kind,
    detail = detail,
    line = line,
    sortText = "2-" .. name,
  }
end

function M.collect_symbols(lines, opts, symbols)
  opts = opts or {}
  symbols = symbols or {}
  local seen_copybooks = opts.seen_copybooks or {}
  for line_number, raw_line in ipairs(lines or {}) do
    local line = raw_line:gsub("^%s*%*.*$", "")
    local copybook = line:match("%f[%a]COPY%s+[\"']?([%w_%-]+)")
    if copybook then
      add_symbol(symbols, copybook, "Copybook", "COPY book", line_number)
      if opts.resolve_copybook and not seen_copybooks[copybook:upper()] then
        seen_copybooks[copybook:upper()] = true
        local copybook_lines = opts.resolve_copybook(copybook)
        if copybook_lines then
          M.collect_symbols(copybook_lines, { resolve_copybook = opts.resolve_copybook, seen_copybooks = seen_copybooks }, symbols)
        end
      end
    end

    local level, name = line:match("^%s*(%d%d)%-?%s+([%w_%-]+)")
    if level and name then
      add_symbol(symbols, name, level_kinds[level] or "Field", "Level " .. level, line_number)
    end

    local paragraph = line:match("^%s*([%w][%w%-]*)%s+SECTION%s*%.")
    if paragraph then add_symbol(symbols, paragraph, "Section", "Procedure Section", line_number) end

    local label = line:match("^%s*([%w][%w%-]*)%s*%.")
    if label and not line:match("DIVISION%s*%.") and not line:match("SECTION%s+SECTION") then
      add_symbol(symbols, label, "Paragraph", "Procedure Paragraph", line_number)
    end
  end
  return symbols
end

local function prefix_matches(label, prefix)
  return prefix == "" or label:sub(1, #prefix):upper() == prefix:upper()
end

function M.complete(lines, prefix, opts)
  prefix = prefix or ""
  local symbols = M.collect_symbols(lines, opts)
  local items = {}
  local seen = {}

  for _, item in ipairs(keyword_items) do
    if prefix_matches(item.label, prefix) then
      items[#items + 1] = vim.deepcopy(item)
      seen[item.label] = true
    end
  end
  for _, item in ipairs(snippet_items) do
    if prefix_matches(item.label, prefix) then items[#items + 1] = vim.deepcopy(item) end
  end
  for label, item in pairs(symbols) do
    if not seen[label] and prefix_matches(label, prefix) then items[#items + 1] = vim.deepcopy(item) end
  end

  table.sort(items, function(a, b)
    if a.sortText ~= b.sortText then return a.sortText < b.sortText end
    return a.label < b.label
  end)
  return items
end

function M.get_keyword_items()
  return vim.deepcopy(keyword_items)
end

function M.get_snippet_items()
  return vim.deepcopy(snippet_items)
end

return M
