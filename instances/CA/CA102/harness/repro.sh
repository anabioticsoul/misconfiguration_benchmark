#!/usr/bin/env bash
set -euo pipefail
log=/tmp/ca102-nginx-test.log
set +e
nginx -t >"$log" 2>&1
status=$?
set -e
cat "$log"
if [ "$status" -eq 0 ]; then
  echo "expected nginx -t to fail" >&2
  exit 1
fi
if ! grep -F "duplicate listen options for [::]:80" "$log" >/dev/null; then
  echo "expected duplicate listen options diagnostic" >&2
  exit 1
fi
