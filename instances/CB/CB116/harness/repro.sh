#!/usr/bin/env bash
set -euo pipefail
output="$(mktemp)"
trap 'rm -f "$output"' EXIT
set +e
mysqld --user=mysql --console >"$output" 2>&1
status=$?
set -e
cat "$output"
test "$status" -ne 0
grep -Fq "Cannot assign requested address" "$output"
