#!/usr/bin/env bash
set -euo pipefail
out=$(mktemp)
trap 'rm -f "$out"' EXIT
set +e
php /opt/cb210/artisan questions:process >"$out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -F 'Allowed memory size' "$out" >/dev/null
