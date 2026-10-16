#!/usr/bin/env bash
# scripts/build_parser.sh
# Builds the extended COBOL Tree-sitter parser shared library with both
# tree_sitter_COBOL (grammar default) and tree_sitter_cobol (Neovim runtime) exports.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
parser_src="$root_dir/tree-sitter-cobol"
target_dir="${1:-${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/parser}"
mkdir -p "$target_dir"
target_so="$target_dir/cobol.so"

alias_c="$(mktemp /tmp/cobol_alias_XXXXXX.c)"
trap 'rm -f "$alias_c"' EXIT

cat << 'EOF' > "$alias_c"
extern const void *tree_sitter_COBOL(void);
const void *tree_sitter_cobol(void) {
    return tree_sitter_COBOL();
}
EOF

CC="${CC:-$(command -v gcc || command -v clang || command -v cc || echo cc)}"
CFLAGS=(-O2 -fPIC -I "$parser_src/src" -I "$parser_src/src/tree_sitter")

if [[ "$(uname -s)" == "Darwin" ]]; then
  "$CC" "${CFLAGS[@]}" -bundle -undefined dynamic_lookup -o "$target_so" \
    "$parser_src/src/parser.c" \
    "$parser_src/src/scanner.c" \
    "$alias_c"
else
  "$CC" "${CFLAGS[@]}" -shared -o "$target_so" \
    "$parser_src/src/parser.c" \
    "$parser_src/src/scanner.c" \
    "$alias_c"
fi

echo "COBOL Tree-sitter parser compiled successfully to: $target_so"
