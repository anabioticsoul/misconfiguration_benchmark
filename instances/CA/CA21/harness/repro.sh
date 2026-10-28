#!/usr/bin/env bash
set -euo pipefail
cd /opt/ca21
set +e
output=$(java -jar app.jar 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -ne 0 ]
printf '%s\n' "$output" | grep -F 'No persistence units parsed from'
