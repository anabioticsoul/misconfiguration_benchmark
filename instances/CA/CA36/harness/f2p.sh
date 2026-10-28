#!/usr/bin/env bash
set -euo pipefail
log=$(mktemp)
trap 'rm -f "$log"' EXIT
set +e
vim -Nu /root/.vimrc -n -es -V1"$log" \
  -c 'let g:leader_hit = 0' \
  -c 'call feedkeys("\<Space>w", "xt")' \
  -c 'if get(g:, "leader_hit", 0) != 1 | cquit 2 | endif' \
  -c 'qa!' >/dev/null 2>"$log"
status=$?
set -e
cat "$log" >&2
if [ "$status" -ne 0 ]; then
  echo 'Space leader mapping did not execute' >&2
  exit 1
fi
