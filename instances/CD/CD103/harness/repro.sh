#!/usr/bin/env bash
set -euo pipefail
url="http://127.0.0.1/this-file-doesnt-exist.php"
set +e
output="$(curl --fail-with-body -sS "$url" 2>&1)"
status=$?
set -e
printf '%s\n' "$output"
test "$status" -ne 0
grep -Fq "File not found" <<<"$output"
