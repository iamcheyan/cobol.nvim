#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for test_file in "$root_dir"/tests/*_spec.lua; do
  nvim --headless -u NONE \
    --cmd "set rtp^=$root_dir" \
    -l "$test_file"
done

echo "cobol.nvim tests: OK"
