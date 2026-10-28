#!/usr/bin/env bash
set -euo pipefail
log=$(mktemp)
trap 'rm -f "$log"' EXIT
if /opt/cd92/run-test.sh >"$log" 2>&1; then
  echo "expected the faulty monthly configuration to fail" >&2
  cat "$log" >&2
  exit 1
fi
cat "$log" >&2
grep -F "expected at least two archived gzip files" "$log" >/dev/null
