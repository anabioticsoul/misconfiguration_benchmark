#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc69
set +e
output=$(mvn -q exec:java 2>&1)
status=$?
set -e
printf '%s\n' "$output"
if [ "$status" -eq 0 ]; then echo 'expected Maven execution failure' >&2; exit 1; fi
printf '%s\n' "$output" | grep -F 'javax/transaction/SystemException' >/dev/null || { echo 'expected missing javax transaction symptom' >&2; exit 1; }
