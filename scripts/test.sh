#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for test_file in "$root_dir"/tests/*_spec.lua; do
  if [[ "$test_file" == *"/ast_spec.lua" || "$test_file" == *"/aerial_spec.lua" ]]; then
    parser_paths="$(nvim --headless -u NONE +'lua io.write(table.concat(vim.api.nvim_get_runtime_file("parser/cobol.so", false), ":"))' +qa)"
    if [[ -z "$parser_paths" && -f "$root_dir/scripts/build_parser.sh" ]]; then
      "$root_dir/scripts/build_parser.sh" >/dev/null 2>&1 || true
      parser_paths="$(nvim --headless -u NONE +'lua io.write(table.concat(vim.api.nvim_get_runtime_file("parser/cobol.so", false), ":"))' +qa)"
    fi
    if [[ -n "$parser_paths" ]]; then
      parser_dir="$(dirname "$parser_paths")"
      extra_rtp=()
      aerial_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/aerial.nvim"
      if [[ -d "$aerial_dir" ]]; then
        extra_rtp+=(--cmd "set rtp^=$aerial_dir")
      fi
      nvim --headless -u NONE \
        --cmd "set rtp^=$root_dir" \
        --cmd "set rtp^=$parser_dir/.." \
        "${extra_rtp[@]}" \
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
