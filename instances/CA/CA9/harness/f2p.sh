#!/usr/bin/env bash
set -euo pipefail
output=''
status=1
for _ in $(seq 1 30); do
  output=$(pg_isready -h 127.0.0.1 -p 5432 2>&1) && { status=0; break; }
  sleep 1
done

printf '%s\n' "$output"
test "$status" -eq 0
