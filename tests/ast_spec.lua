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
assert(#rainbow_state.active == 3, "All 3 active levels should be marked")
assert(rainbow_state.active[1].depth == 3, "Active[1] must be innermost depth 3")

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
  -- Confirm dialect boundaries: XML, JSON, EXEC SQL, OO COBOL are absent from COBOL 85 grammar
  assert(not grammar_syms["xml_parse_statement"], "xml_parse_statement must not be claimed unless grammar supports it")
  assert(not grammar_syms["json_parse_statement"], "json_parse_statement must not be claimed unless grammar supports it")
  assert(not grammar_syms["exec_sql_statement"], "exec_sql_statement must not be claimed unless grammar supports it")
  assert(not grammar_syms["class_id_header"], "class_id_header must not be claimed unless grammar supports it")
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

print("ast_spec: OK")
