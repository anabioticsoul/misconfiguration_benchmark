#!/usr/bin/env bash
set -euo pipefail
out=$(mktemp)
trap 'rm -f "$out"' EXIT
php /opt/cb210/artisan questions:single >"$out" 2>&1
grep -F 'single question: 1' "$out" >/dev/null
