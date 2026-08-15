#!/usr/bin/env bash
set -euo pipefail
command -v nginx >/dev/null
set +e
output=$(nginx -t 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -ne 0 ]
printf '%s\n' "$output" | grep -F 'fastcgi_pass' >/dev/null
printf '%s\n' "$output" | grep -F 'not allowed here' >/dev/null
printf '%s\n' "$output" | grep -F 'default~' >/dev/null
