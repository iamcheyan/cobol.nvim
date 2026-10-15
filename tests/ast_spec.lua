-- Run with the optional tree-sitter-cobol parser on runtimepath.
local ast = require("cobol.ast")

vim.cmd("enew")
vim.bo.filetype = "cobol"
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "       IDENTIFICATION DIVISION.",
  "       PROGRAM-ID. ASTTEST.",
  "       PROCEDURE DIVISION.",
  "       MAIN-PARA.",
  "           IF WS-A = ZERO",
  "               EVALUATE WS-B",
  "                 WHEN ZERO",
  "                   PERFORM UNTIL WS-C = ZERO",
  "                     DISPLAY \"OK\"",
  "                   END-PERFORM",
  "               END-EVALUATE",
  "           END-IF.",
})

local root, err = ast.parser(0)
assert(root, err)
local structures = ast.structures(0)
assert(#structures == 3, "parser should expose nested IF, EVALUATE, and PERFORM nodes")
assert(structures[1].name == "IF" and structures[2].name == "EVALUATE" and structures[3].name == "PERFORM")
assert(structures[1].start_row == 4 and structures[1].depth == 1)
assert(structures[2].start_row == 5 and structures[2].depth == 2)
assert(structures[3].start_row == 7 and structures[3].depth == 3)

local inner = ast.at_cursor(0, 8, 25)
assert(#inner == 3 and inner[1].name == "PERFORM" and inner[3].name == "IF", "cursor ancestry should be AST ordered")
local stack = ast.closure_stack(0, 8, 25)
assert(stack[1]:find("END%-PERFORM") and stack[2]:find("END%-EVALUATE") and stack[3]:find("END%-IF"), "closure stack should be inner-first")
assert(ast.textobject(0, 8, 25, "IF", false), "outer textobject should resolve")
assert(ast.textobject(0, 8, 25, "EVALUATE", true), "inner textobject should resolve")
local mate = ast.jump_match(0, 4, 13)
assert(mate and mate[1] == 11, "opening IF should jump to its AST matched END-IF")

print("ast_spec: OK")
