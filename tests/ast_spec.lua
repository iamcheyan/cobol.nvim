-- Comprehensive AST integration tests for COBOL structure navigation
local ast = require("cobol.ast")
local folding = require("cobol.folding")

vim.cmd("enew")
vim.bo.filetype = "cobol"

-- 1. Test nested structures, breadcrumbs, WHEN, and waiting closures
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. ASTTEST.",
  "       PROCEDURE DIVISION.",
  "       INPUT-SECTION SECTION.",
  "       VALIDATE-INPUT.",
  "           IF STATUS = \"A\"",
  "               EVALUATE TXN-TYPE",
  "                 WHEN \"D\"",
  "                   DISPLAY \"OK\"",
  "               END-EVALUATE",
  "           END-IF.",
})

local root, err = ast.parser(0)
assert(root, err or "Parser root must be non-nil")
local structures = ast.structures(0)
assert(#structures == 2, "Must detect IF and EVALUATE")
assert(structures[1].name == "IF" and structures[1].depth == 1)
assert(structures[2].name == "EVALUATE" and structures[2].depth == 2)

-- Breadcrumb test at line 8 (0-indexed row 8, col 20 = DISPLAY "OK")
vim.api.nvim_win_set_cursor(0, { 9, 20 })
local state = ast.update(0, 0)
assert(state, "AST update should return state")
assert(state.breadcrumb:find("PROCEDURE DIVISION"), "Breadcrumb must include Division")
assert(state.breadcrumb:find("INPUT%-SECTION"), "Breadcrumb must include Section")
assert(state.breadcrumb:find("VALIDATE%-INPUT"), "Breadcrumb must include Paragraph")
assert(state.breadcrumb:find("IF STATUS"), "Breadcrumb must include IF condition")
assert(state.breadcrumb:find("EVALUATE TXN%-TYPE"), "Breadcrumb must include EVALUATE")
assert(state.breadcrumb:find("WHEN"), "Breadcrumb must include WHEN clause")

-- Waiting closures at line 8: innermost (END-EVALUATE) before outer (END-IF)
local waiting = ast.closure_stack(0, 8, 20)
assert(#waiting == 2, "Waiting stack must have 2 closures")
assert(waiting[1]:find("END%-EVALUATE"), "Innermost closure must be first: " .. waiting[1])
assert(waiting[2]:find("END%-IF"), "Outermost closure must be second: " .. waiting[2])

-- 2. Test foldtext for AST structures
local fold_if = ast.foldtext_for_line(0, 6)
assert(fold_if:find("+%-%- IF STATUS = \"A\""), "Foldtext for line 6 should show IF summary: " .. fold_if)
local fold_eval = ast.foldtext_for_line(0, 7)
assert(fold_eval:find("+%-%- EVALUATE TXN%-TYPE"), "Foldtext for line 7 should show EVALUATE summary: " .. fold_eval)

-- 3. Test text objects
local outer_if = ast.textobject(0, 8, 20, "IF", false)
assert(outer_if and outer_if[1] == 5 and outer_if[3] == 10, "Outer IF textobject should span lines 6 to 11")
local inner_if = ast.textobject(0, 8, 20, "IF", true)
assert(inner_if and inner_if[1] == 5 and inner_if[3] == 10, "Inner IF textobject should span inside")

-- 4. Test bidirectional % matching jump
local jump_from_start = ast.jump_match(0, 5, 12)
assert(jump_from_start and jump_from_start[1] == 10, "Start IF must jump to END-IF line 10 (0-indexed)")
local jump_from_end = ast.jump_match(0, 10, 12)
assert(jump_from_end and jump_from_end[1] == 5, "END-IF must jump back to start IF line 5 (0-indexed)")

-- 5. Test all COBOL 85 closed structures:
--    IF, EVALUATE, PERFORM, SEARCH, READ, WRITE, REWRITE, DELETE, START, STRING, UNSTRING
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. ALLSTRUCTURES.",
  "       PROCEDURE DIVISION.",
  "       TEST-ALL.",
  "      * False keyword in comment: END-IF END-PERFORM END-READ",
  "           DISPLAY \"False keyword in string: END-EVALUATE END-WRITE\"",
  "           IF COND-A > 0",
  "               DISPLAY \"A\"",
  "           END-IF",
  "           EVALUATE COND-B",
  "               WHEN 1 DISPLAY \"1\"",
  "           END-EVALUATE",
  "           PERFORM UNTIL EOF-FLAG",
  "               DISPLAY \"LOOP\"",
  "           END-PERFORM",
  "           SEARCH TABLE-A",
  "               WHEN KEY-A = 1 DISPLAY \"FOUND\"",
  "           END-SEARCH",
  "           READ FILE-A INTO REC-A",
  "               AT END DISPLAY \"EOF\"",
  "           END-READ",
  "           WRITE REC-A",
  "               INVALID KEY DISPLAY \"ERR\"",
  "           END-WRITE",
  "           REWRITE REC-A",
  "               INVALID KEY DISPLAY \"ERR\"",
  "           END-REWRITE",
  "           DELETE FILE-A RECORD",
  "               INVALID KEY DISPLAY \"ERR\"",
  "           END-DELETE",
  "           START FILE-A KEY IS EQUAL TO KEY-A",
  "               INVALID KEY DISPLAY \"ERR\"",
  "           END-START",
  "           STRING FLD-A DELIMITED BY SIZE INTO FLD-B",
  "               ON OVERFLOW DISPLAY \"OVF\"",
  "           END-STRING",
  "           UNSTRING FLD-B DELIMITED BY SPACE INTO FLD-A",
  "               ON OVERFLOW DISPLAY \"OVF\"",
  "           END-UNSTRING",
})

local all_structs = ast.structures(0)
local expected_names = {
  "IF", "EVALUATE", "PERFORM", "SEARCH", "READ", "WRITE", "REWRITE", "DELETE", "START", "STRING", "UNSTRING"
}
local found_names = {}
for _, s in ipairs(all_structs) do
  found_names[s.name] = true
  assert(s.close_row, "Structure " .. s.name .. " must have a paired close_row")
  -- Verify % jump for each structure
  local forward = ast.jump_match(0, s.start_row, s.start_col)
  assert(forward and forward[1] == s.close_row, "% forward jump failed for " .. s.name)
  local backward = ast.jump_match(0, s.close_row, s.close_col)
  assert(backward and backward[1] == s.start_row, "% backward jump failed for " .. s.name)
end

for _, name in ipairs(expected_names) do
  assert(found_names[name], "Missing expected structure: " .. name)
end

-- 6. Verify comments and strings did NOT create false structures
assert(#all_structs == #expected_names, string.format("Expected %d structures, got %d", #expected_names, #all_structs))

-- 7. Test format with inline *> comments
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. COMMENTTEST.",
  "       PROCEDURE DIVISION.",
  "       COMMENT-PARA.",
  "           *> This is a modern comment",
  "           IF TEST-VAL = 1",
  "               DISPLAY \"TEST\"",
  "           END-IF.",
})
local comment_structs = ast.structures(0)
assert(#comment_structs == 1 and comment_structs[1].name == "IF", "IF with inline comment must be detected")

-- 8. Test 3-level rainbow nesting depth colors
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. RAINBOW.",
  "       PROCEDURE DIVISION.",
  "       RAINBOW-PARA.",
  "           IF A",
  "               IF B",
  "                   IF C",
  "                       DISPLAY \"OK\"",
  "                   END-IF",
  "               END-IF",
  "           END-IF.",
})

local rainbow_structs = ast.structures(0)
assert(#rainbow_structs == 3)
assert(rainbow_structs[1].depth == 1, "Level 1 IF must have depth 1")
assert(rainbow_structs[2].depth == 2, "Level 2 IF must have depth 2")
assert(rainbow_structs[3].depth == 3, "Level 3 IF must have depth 3")

-- Move cursor to IF C (line 7, 0-indexed row 6) and test update
vim.api.nvim_win_set_cursor(0, { 7, 20 })
local rainbow_state = ast.update(0, 0)
assert(#rainbow_state.active == 3, "All 3 active levels should be tracked in active state")
assert(rainbow_state.active[1].depth == 3, "Active[1] must be innermost depth 3")

-- Visual highlight extmarks must ONLY be applied to the innermost structure (depth 3)
local rainbow_marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("cobol_ast_navigation"), 0, -1, { details = true })
local has_s1, has_s2, has_s3 = false, false, false
for _, m in ipairs(rainbow_marks) do
  local details = m[4]
  if details.hl_group == "CobolStructure1" then has_s1 = true end
  if details.hl_group == "CobolStructure2" then has_s2 = true end
  if details.hl_group == "CobolStructure3" then has_s3 = true end
end
assert(has_s3, "Innermost structure (depth 3) must be highlighted")
assert(not has_s1 and not has_s2, "Outer enclosing structures must NOT be visually highlighted simultaneously")

-- Test statusline and floating window APIs
local stl = ast.statusline(0)
assert(stl:find("RAINBOW%-PARA"), "Statusline should contain paragraph name: " .. stl)
local win_crumb = ast.show_breadcrumb_float(0)
assert(win_crumb and vim.api.nvim_win_is_valid(win_crumb), "Floating breadcrumb window must open")
vim.api.nvim_win_close(win_crumb, true)

local win_wait = ast.show_waiting_closures_float(0)
assert(win_wait and vim.api.nvim_win_is_valid(win_wait), "Floating waiting closures window must open")
vim.api.nvim_win_close(win_wait, true)

-- 9. Verify every mapped entry in ast.kinds exists as a valid symbol in loaded Tree-sitter grammar
local ffi = require("ffi")
ffi.cdef[[
  typedef struct TSLanguage TSLanguage;
  const TSLanguage *tree_sitter_cobol(void);
  uint32_t ts_language_symbol_count(const TSLanguage *);
  const char *ts_language_symbol_name(const TSLanguage *, uint16_t);
]]
local parser_paths = vim.api.nvim_get_runtime_file("parser/cobol.so", false)
if #parser_paths > 0 then
  local clib = ffi.load(parser_paths[1])
  local ts_lang = clib.tree_sitter_cobol()
  local sym_count = ffi.C.ts_language_symbol_count(ts_lang)
  local grammar_syms = {}
  for i = 0, sym_count - 1 do
    local sname = ffi.string(ffi.C.ts_language_symbol_name(ts_lang, i))
    grammar_syms[sname] = true
  end
  for k, spec in pairs(ast.kinds) do
    assert(grammar_syms[k], "AST start node type '" .. k .. "' does not exist in COBOL tree-sitter grammar")
    assert(grammar_syms[spec.end_node], "AST end node type '" .. spec.end_node .. "' does not exist in COBOL tree-sitter grammar")
  end
  -- Confirm all dialect extension nodes are present
  assert(grammar_syms["xml_parse_statement"] and grammar_syms["END_XML"], "xml_parse_statement and END_XML must exist in grammar")
  assert(grammar_syms["json_parse_statement"] and grammar_syms["END_JSON"], "json_parse_statement and END_JSON must exist in grammar")
  assert(grammar_syms["exec_sql_statement"] and grammar_syms["END_EXEC"], "exec_sql_statement and END_EXEC must exist in grammar")
  assert(grammar_syms["class_id_header"] and grammar_syms["END_CLASS"], "class_id_header and END_CLASS must exist in grammar")
  assert(grammar_syms["method_id_header"] and grammar_syms["END_METHOD"], "method_id_header and END_METHOD must exist in grammar")
  assert(grammar_syms["factory_header"] and grammar_syms["END_FACTORY"], "factory_header and END_FACTORY must exist in grammar")
  assert(grammar_syms["object_header"] and grammar_syms["END_OBJECT"], "object_header and END_OBJECT must exist in grammar")
end

-- 10. Test % mapping and textobjects from configured Neovim buffer
local cobol = require("cobol")
cobol.setup({})

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. KEYTEST.",
  "       PROCEDURE DIVISION.",
  "       KEY-PARA.",
  "           IF STATUS = \"A\"",
  "               EVALUATE TXN-TYPE",
  "                   WHEN \"D\"",
  "                       DISPLAY \"D\"",
  "               END-EVALUATE",
  "           END-IF.",
})
vim.bo.filetype = "cobol"

-- Test % jump forward from IF (line 5) to END-IF (line 10)
vim.api.nvim_win_set_cursor(0, { 5, 11 })
vim.cmd("normal %")
assert(vim.api.nvim_win_get_cursor(0)[1] == 10, "% should jump from IF (line 5) to END-IF (line 10)")

-- Test % jump backward from END-IF (line 10) to IF (line 5)
vim.cmd("normal %")
assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "% should jump backward from END-IF (line 10) to IF (line 5)")

-- 11. Test dialect structures in Neovim buffer (XML, JSON, EXEC SQL, OO COBOL)
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. DIALECTTEST.",
  "       PROCEDURE DIVISION.",
  "       DIALECT-PARA.",
  "           XML PARSE DOC-VAR",
  "               DISPLAY \"XML\"",
  "           END-XML",
  "           JSON PARSE JSON-VAR",
  "               DISPLAY \"JSON\"",
  "           END-JSON",
  "           EXEC SQL",
  "               SELECT * FROM CUSTOMER",
  "           END-EXEC",
  "           FACTORY.",
  "           END FACTORY.",
  "           OBJECT.",
  "           END OBJECT.",
})
vim.bo.filetype = "cobol"

local dialect_structs = ast.structures(0)
local dialect_names = {}
for _, s in ipairs(dialect_structs) do
  dialect_names[s.name] = s
end

assert(dialect_names["XML PARSE"], "XML PARSE must be detected in AST structures")
assert(dialect_names["JSON PARSE"], "JSON PARSE must be detected in AST structures")
assert(dialect_names["EXEC SQL"], "EXEC SQL must be detected in AST structures")
assert(dialect_names["FACTORY"], "FACTORY must be detected in AST structures")
assert(dialect_names["OBJECT"], "OBJECT must be detected in AST structures")

-- Test % jump for EXEC SQL: line 11 (row 10) <-> line 13 (row 12)
local sql_forward = ast.jump_match(0, 10, 11)
assert(sql_forward and sql_forward[1] == 12, "% jump forward from EXEC SQL to END-EXEC")
local sql_back = ast.jump_match(0, 12, 11)
assert(sql_back and sql_back[1] == 10, "% jump backward from END-EXEC to EXEC SQL")

-- Test % jump for XML PARSE: line 5 (row 4) <-> line 7 (row 6)
local xml_forward = ast.jump_match(0, 4, 11)
assert(xml_forward and xml_forward[1] == 6, "% jump forward from XML PARSE to END-XML")
local xml_back = ast.jump_match(0, 6, 11)
assert(xml_back and xml_back[1] == 4, "% jump backward from END-XML to XML PARSE")

-- Test % jump for JSON PARSE: line 8 (row 7) <-> line 10 (row 9)
local json_forward = ast.jump_match(0, 7, 11)
assert(json_forward and json_forward[1] == 9, "% jump forward from JSON PARSE to END-JSON")
local json_back = ast.jump_match(0, 9, 11)
assert(json_back and json_back[1] == 7, "% jump backward from END-JSON to JSON PARSE")

-- Test foldtext for SQL
local fold_sql = ast.foldtext_for_line(0, 11)
assert(fold_sql:find("SQL SELECT"), "Foldtext for line 11 should show SQL SELECT: " .. fold_sql)

-- 12. Breadcrumb must be an exact structural chain, not a dump of the division
-- text. The vendored grammar keeps headers, bodies and END-* tokens as flat
-- siblings, so ancestry-based chains used to print the whole PROCEDURE DIVISION.
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. CHAINTEST.",
  "       PROCEDURE DIVISION.",
  "       INPUT-SECTION SECTION.",
  "       VALIDATE-INPUT.",
  "           IF STATUS = \"A\"",
  "               EVALUATE TXN-TYPE",
  "                 WHEN \"D\"",
  "                   DISPLAY \"OK\"",
  "               END-EVALUATE",
  "           END-IF.",
})
vim.bo.filetype = "cobol"
vim.api.nvim_win_set_cursor(0, { 9, 20 })
local chain_state = ast.update(0, 0)
local expected_chain = 'PROCEDURE DIVISION > INPUT-SECTION > VALIDATE-INPUT > IF STATUS = "A" > EVALUATE TXN-TYPE > WHEN "D"'
assert(chain_state.breadcrumb == expected_chain,
  "Breadcrumb must be the exact chain, got: " .. chain_state.breadcrumb)
assert(not chain_state.breadcrumb:find("DISPLAY", 1, true),
  "Breadcrumb must not contain raw statement text: " .. chain_state.breadcrumb)
assert(not chain_state.breadcrumb:find("STOP RUN", 1, true),
  "Breadcrumb must not contain the division body: " .. chain_state.breadcrumb)
assert(ast.chain(0, 8, 20)[1] == "PROCEDURE DIVISION", "chain() must return the parts, outermost first")

-- WHEN must sit before structures nested inside its body
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. WHENORDER.",
  "       PROCEDURE DIVISION.",
  "       ORDER-PARA.",
  "           EVALUATE TXN-TYPE",
  "             WHEN 1",
  "                 PERFORM UNTIL EOF-FLAG",
  "                     DISPLAY \"LOOP\"",
  "                 END-PERFORM",
  "           END-EVALUATE.",
})
vim.api.nvim_win_set_cursor(0, { 8, 25 })
local when_order = ast.update(0, 0).breadcrumb
assert(when_order == "PROCEDURE DIVISION > ORDER-PARA > EVALUATE TXN-TYPE > WHEN 1 > PERFORM UNTIL EOF-FLAG",
  "WHEN must precede structures nested in its body, got: " .. when_order)

-- 13. ast.update must survive a window that shows another buffer (winbar and
-- statusline are evaluated for windows that are not the current one).
local cobol_buf = vim.api.nvim_get_current_buf()
local scratch = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "not cobol" })
vim.cmd("split")
vim.api.nvim_set_current_buf(scratch)
local guard_ok, guard_state = pcall(ast.update, cobol_buf, vim.api.nvim_get_current_win())
assert(guard_ok, "ast.update must clamp a cursor that belongs to another buffer: " .. tostring(guard_state))
assert(guard_state and type(guard_state.breadcrumb) == "string",
  "ast.update must still return state for the COBOL buffer")
assert(pcall(ast.chain, cobol_buf, -5, -5), "chain() must tolerate a negative position")
vim.cmd("close")

-- 14. EXEC SQL statements whose body is not a bare SELECT must still pair with
-- END-EXEC (regression: the grammar produced an ERROR node that swallowed it).
local sql_variants = {
  { "UPDATE", { "UPDATE EMP SET EMP_NAME = 'NO_NAME' WHERE EMP_NO > :EMP-NO" }, "SQL UPDATE" },
  { "DELETE", { "DELETE FROM EMP WHERE EMP_NO = :EMP-NO" }, "SQL DELETE" },
  { "DECLARE CURSOR", { "DECLARE C1 CURSOR FOR", "    SELECT EMP_NO FROM EMP" }, "SQL CURSOR" },
}
for _, variant in ipairs(sql_variants) do
  local lines = {
    "       IDENTIFICATION DIVISION.",
    "       PROGRAM-ID. SQLVARIANT.",
    "       PROCEDURE DIVISION.",
    "           EXEC SQL",
  }
  for _, body in ipairs(variant[2]) do
    lines[#lines + 1] = "               " .. body
  end
  lines[#lines + 1] = "           END-EXEC."
  lines[#lines + 1] = "           STOP RUN."
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

  local end_exec_row = 4 + #variant[2]
  local variants = ast.structures(0)
  local found
  for _, s in ipairs(variants) do
    if s.name == "EXEC SQL" then found = s end
  end
  assert(found, "EXEC SQL must be detected for " .. variant[1])
  assert(found.close_row == end_exec_row,
    "EXEC SQL must pair with END-EXEC for " .. variant[1] .. ", got close_row=" .. tostring(found.close_row))
  assert(found.label == variant[3],
    "EXEC SQL label for " .. variant[1] .. " must be " .. variant[3] .. ", got " .. found.label)
  local forward = ast.jump_match(0, 3, 12)
  assert(forward and forward[1] == end_exec_row, "% must jump to END-EXEC for " .. variant[1])
  local backward = ast.jump_match(0, end_exec_row, 12)
  assert(backward and backward[1] == 3, "% must jump back to EXEC SQL for " .. variant[1])
  assert(#ast.closure_stack(0, 3, 20) == 1, "EXEC SQL must appear in the waiting closures for " .. variant[1])
end

-- 15. ensure_parser returns true when parser/cobol.so is already installed
local ensure_called = false
local ensure_ok = ast.ensure_parser(function(ok)
  ensure_called = true
  assert(ok, "ensure_parser callback must receive true when parser is present")
end)
assert(ensure_ok == true, "ensure_parser must return true when parser is present")
-- 16. Structure scope: highlights and dashed connecting lines
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. SCOPETEST.",
  "       PROCEDURE DIVISION.",
  "       MAIN-PARA.",
  "           IF A > 1",
  "               DISPLAY \"INSIDE\"",
  "           END-IF.",
})
vim.api.nvim_win_set_cursor(0, { 6, 20 })
local scope_state = ast.update(0, 0)
assert(#scope_state.active == 1, "One active structure should be found at cursor")
local marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("cobol_ast_navigation"), 0, -1, { details = true })
local has_opening_badge = false
local has_closing_badge = false
local has_connecting_line = false
for _, m in ipairs(marks) do
  local row, col, details = m[2], m[3], m[4]
  if details.hl_group and details.hl_group:find("CobolStructure%d") then
    if row == 4 then has_opening_badge = true end
    if row == 6 then has_closing_badge = true end
  end
  if details.virt_text and details.virt_text[1] and details.virt_text[1][1]:find("┆") then
    if row == 5 and col == 11 then has_connecting_line = true end
  end
end
assert(has_opening_badge, "Opening IF should have structure badge")
assert(has_closing_badge, "Closing END-IF should have structure badge")
assert(has_connecting_line, "Body line should have connecting dashed line")

-- 17. IF with ELSE and Paragraph Scope
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. BRANCHTEST.",
  "       PROCEDURE DIVISION.",
  "       8100-LOG.",
  "           IF WS-STATUS = \"00\"",
  "               DISPLAY \"OK\"",
  "           ELSE",
  "               DISPLAY \"ERR\"",
  "           END-IF.",
  "       8200-EXIT.",
  "           STOP RUN.",
})
vim.api.nvim_win_set_cursor(0, { 6, 20 })
local branch_state = ast.update(0, 0)
assert(#branch_state.active == 1, "IF should be active")
local b_marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("cobol_ast_navigation"), 0, -1, { details = true })
local has_else_badge = false
local has_para_badge = false
for _, m in ipairs(b_marks) do
  local row, col, details = m[2], m[3], m[4]
  if details.hl_group and details.hl_group:find("CobolStructure%d") and row == 6 then
    has_else_badge = true
  end
  if details.hl_group == "CobolParagraphScope" then
    has_para_badge = true
  end
end
assert(has_else_badge, "ELSE keyword must have structure badge")
assert(not has_para_badge, "Paragraph headers must NOT have orphaned badges")

-- 18. Active scope recording for line ruler coordination
assert(ast.active_scope ~= nil, "ast.active_scope must be recorded for active structure")
assert(ast.active_scope.col == 11, "Active structure must have col 11 (Area B)")
assert(ast.active_scope.char == "┆", "Active structure scope char must be ┆")

print("ast_spec: OK")
