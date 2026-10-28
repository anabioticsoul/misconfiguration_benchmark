#!/usr/bin/env bash
set -euo pipefail
out=$(mktemp)
trap 'rm -f "$out"' EXIT
set +e
/opt/cc54/check.py >"$out" 2>&1
status=$?
set -e
cat "$out"
[ "$status" -ne 0 ]
grep -F "Could not load file or assembly 'System.Web.Helpers, Version=1.0.0.0" "$out" >/dev/null
