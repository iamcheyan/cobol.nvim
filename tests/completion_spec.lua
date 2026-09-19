local completion = require("cobol.completion")

local lines = {
  "       IDENTIFICATION DIVISION.",
  "       DATA DIVISION.",
  "       WORKING-STORAGE SECTION.",
  "       01  WS-STATUS.",
  "           05  WS-EOF       PIC X VALUE \"N\".",
  "               88  EOF-YES VALUE \"Y\".",
  "       PROCEDURE DIVISION.",
  "       0000-MAIN.",
  "           COPY EMP-REC.",
  "           PERFORM 1000-INITIALIZE.",
  "       1000-INITIALIZE SECTION.",
  "           MOVE \"N\" TO WS-EOF.",
}

local symbols = completion.collect_symbols(lines)
assert(symbols["WS-EOF"] and symbols["WS-EOF"].kind == "Field", "data fields should be collected")
assert(symbols["EOF-YES"] and symbols["EOF-YES"].kind == "Condition", "88-level conditions should be collected")
assert(symbols["1000-INITIALIZE"] and symbols["1000-INITIALIZE"].kind == "Section", "sections should be collected")
assert(symbols["0000-MAIN"] and symbols["0000-MAIN"].kind == "Paragraph", "paragraphs should be collected")
assert(symbols["EMP-REC"] and symbols["EMP-REC"].kind == "Copybook", "copybooks should be collected")

local copybook_symbols = completion.collect_symbols({ "       COPY EMP-REC." }, {
  resolve_copybook = function(name)
    assert(name == "EMP-REC", "copybook resolver should receive the copybook name")
    return { "       01  EMP-RECORD.", "           05  EMP-ID PIC X(5)." }
  end,
})
assert(copybook_symbols["EMP-ID"] and copybook_symbols["EMP-ID"].kind == "Field", "copybook fields should be collected")

local items = completion.complete(lines, "WS-")
assert(#items == 2 and items[1].label == "WS-EOF" and items[2].label == "WS-STATUS", "completion should filter symbols by prefix")

local keywords = completion.complete(lines, "PERF")
local found_perform = false
for _, item in ipairs(keywords) do
  if item.label == "PERFORM" and item.kind == "Keyword" then found_perform = true end
end
assert(found_perform, "completion should include COBOL keywords")

local snippets = completion.complete(lines, "IF")
local found_if_snippet = false
for _, item in ipairs(snippets) do
  if item.kind == "Snippet" and item.insertText:find("END%-IF", 1, false) then found_if_snippet = true end
end
assert(found_if_snippet, "completion should include an IF scope snippet")

print("completion_spec: OK")
