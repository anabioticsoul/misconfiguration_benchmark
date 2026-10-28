#!/usr/bin/env bash
set -euo pipefail
log=/tmp/ca41-f2p.log
set +e
nginx -t >"$log" 2>&1
status=$?
set -e
cat "$log"
[ "$status" -eq 0 ]
if grep -Fq 'the "ssl" directive is deprecated' "$log"; then
  echo 'deprecated SSL directive remains' >&2
  exit 1
fi
