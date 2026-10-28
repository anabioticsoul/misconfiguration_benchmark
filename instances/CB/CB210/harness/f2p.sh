#!/usr/bin/env bash
set -euo pipefail
out=$(mktemp)
trap 'rm -f "$out"' EXIT
php /opt/cb210/artisan questions:process >"$out" 2>&1
grep -F 'processed 50000 questions' "$out" >/dev/null
