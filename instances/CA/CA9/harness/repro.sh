#!/usr/bin/env bash
set -euo pipefail
output=$(pg_isready -h 127.0.0.1 -p 5432 2>&1) && status=0 || status=$?
printf '%s\n' "$output"
test "$status" -ne 0
grep -Fq 'no response' <<<"$output"
