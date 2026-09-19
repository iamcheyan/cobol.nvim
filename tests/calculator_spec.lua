local calculator = require("cobol.calculator")

local function assert_equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s", label, expected, actual))
end

local comp1 = assert(calculator.parse_field_size("       05 WS-FLOAT PIC S9(4) COMP-1."))
assert_equal(comp1.usage, "COMP-1", "COMP-1 usage")
assert_equal(comp1.bytes, 4, "COMP-1 size")

local comp2 = assert(calculator.parse_field_size("       05 WS-DOUBLE PIC S9(9) COMP-2."))
assert_equal(comp2.usage, "COMP-2", "COMP-2 usage")
assert_equal(comp2.bytes, 8, "COMP-2 size")

local comp3 = assert(calculator.parse_field_size("       05 WS-PACKED PIC S9(5)V99 COMP-3."))
assert_equal(comp3.usage, "COMP-3", "COMP-3 usage")
assert_equal(comp3.bytes, 4, "COMP-3 size")

local separate = assert(calculator.parse_field_size("       05 WS-AMOUNT PIC S9(3) SIGN IS SEPARATE."))
assert_equal(separate.bytes, 4, "separate display sign size")

for digits, expected in pairs({ [4] = 2, [5] = 4, [9] = 4, [10] = 8 }) do
  local field = assert(calculator.parse_field_size(string.format("       05 WS-BIN PIC 9(%d) BINARY.", digits)))
  assert_equal(field.bytes, expected, "binary boundary " .. digits)
end

print("calculator_spec: OK")
