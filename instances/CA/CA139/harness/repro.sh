#!/usr/bin/env bash
set -euo pipefail

set +e
output="$(/usr/local/bin/ca139-export 2>&1)"
status=$?
set -e
printf '%s\n' "$output"

if [[ "$status" -eq 0 ]]; then
    echo "expected the PHP export to fail at the 1G limit" >&2
    exit 1
fi
if [[ "$output" != *"Allowed memory size of 1073741824 bytes exhausted"* ]]; then
    echo "missing expected PHP memory-limit diagnostic" >&2
    exit 1
fi
