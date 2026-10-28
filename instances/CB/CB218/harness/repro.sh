#!/usr/bin/env bash
set -euo pipefail
cd /opt/ted-search
set +e
output=$(java -cp /opt/ted-search App 2>&1)
status=$?
set -e
printf '%s\n' "$output"
test "$status" -ne 0
printf '%s\n' "$output" | grep -F "No cache manager could be auto-configured" >/dev/null
printf '%s\n' "$output" | grep -F "caching type is 'GENERIC'" >/dev/null
