#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for test_file in "$root_dir"/tests/*_spec.lua; do
  if [[ "$test_file" == *"/ast_spec.lua" || "$test_file" == *"/aerial_spec.lua" ]]; then
    parser_paths="$(nvim --headless -u NONE +'lua io.write(table.concat(vim.api.nvim_get_runtime_file("parser/cobol.so", false), ":"))' +qa)"
    if [[ -n "$parser_paths" ]]; then
      parser_dir="$(dirname "$parser_paths")"
      nvim --headless -u NONE \
        --cmd "set rtp^=$root_dir" \
        --cmd "set rtp^=$parser_dir/.." \
        -l "$test_file"
      continue
    fi
    if [[ "$test_file" == *"/ast_spec.lua" ]]; then
      echo "ast_spec: SKIP (install tree-sitter-cobol parser to run AST integration checks)"
      continue
    fi
  fi
  nvim --headless -u NONE \
    --cmd "set rtp^=$root_dir" \
    -l "$test_file"
done

echo "cobol.nvim tests: OK"
