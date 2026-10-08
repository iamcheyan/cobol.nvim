local indent = require("cobol.indent")

local procedure = {
  "       PROCEDURE DIVISION.",
  "       MAIN-PARA.",
  "           IF WS-READY = 'Y'",
  "",
}
assert(indent.compute(procedure, 4) == 15, "statements inside IF should indent one Area-B level")
procedure[4] = "           END-IF"
assert(indent.compute(procedure, 4) == 11, "END-IF should align with its opening IF")

local nested = {
  "       PROCEDURE DIVISION.",
  "       MAIN-PARA.",
  "           EVALUATE WS-CODE",
  "           WHEN 'A'",
  "               IF WS-READY = 'Y'",
  "",
}
assert(indent.compute(nested, 4) == 11, "WHEN clauses should align with EVALUATE")
assert(indent.compute(nested, 6) == 19, "nested EVALUATE and IF blocks should advance within Area B")
local read_block = {
  "       PROCEDURE DIVISION.",
  "       MAIN-PARA.",
  "           READ INPUT-FILE",
  "           AT END",
  "",
}
assert(indent.compute(read_block, 4) == 15, "a multiline READ should indent its AT END branch")
read_block[4] = "           END-READ"
assert(indent.compute(read_block, 4) == 11, "END-READ should align with its opening READ")
local literal_period = {
  "       PROCEDURE DIVISION.",
  "       MAIN-PARA.",
  "           IF WS-READY = 'Y'",
  "               DISPLAY \"A PERIOD.\"",
  "",
}
assert(indent.compute(literal_period, 5) == 15, "a period inside a literal must not close an open COBOL scope")

local data = {
  "       DATA DIVISION.",
  "       WORKING-STORAGE SECTION.",
  "       01 WS-RECORD.",
  "           05 WS-GROUP.",
  "",
}
assert(indent.compute(data, 5) == 15, "nested fixed-format data levels should indent by level")

local numbered = { "000100  DISPLAY 'KEEP'." }
assert(indent.compute(numbered, 1) == -1, "sequence-numbered source lines should keep their columns")
local continued = { "       PROCEDURE DIVISION.", "      -    DISPLAY 'CONTINUED'." }
assert(indent.compute(continued, 2) == -1, "continuation indicator lines should keep their source columns")
local reference = "           DISPLAY 'SAFE'." .. string.rep(" ", 72 - #"           DISPLAY 'SAFE'.") .. "REF"
assert(#reference > 72 and indent.compute({ "       PROCEDURE DIVISION.", reference }, 2) == -1,
  "reindent must skip lines with reference-area content so columns 73-80 stay unchanged")
assert(indent.compute({ "       PROCEDURE DIVISION.", "      * KEEP COMMENT" }, 2) == -1,
  "fixed-format comment lines should keep their indicator column")

print("indent_spec: OK")
