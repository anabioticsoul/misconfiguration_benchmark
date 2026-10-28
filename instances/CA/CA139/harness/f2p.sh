#!/usr/bin/env bash
set -euo pipefail

set +e
output="$(/usr/local/bin/ca139-export 2>&1)"
status=$?
set -e
printf '%s\n' "$output"

if [[ "$status" -ne 0 ]]; then
    echo "PHP product export did not complete after repair" >&2
    exit 1
fi
if [[ "$output" != *"export-ok 1101004800"* ]]; then
    echo "successful export did not report the expected payload" >&2
    exit 1
fi
