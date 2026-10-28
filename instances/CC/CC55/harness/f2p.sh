#!/usr/bin/env bash
set -euo pipefail

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT
set +e
/usr/local/bin/intellij-spring-check >"$output_file" 2>&1
status=$?
set -e
cat "$output_file"

if [ "$status" -ne 0 ]; then
  printf '%s\n' 'Spring facet check did not succeed.' >&2
  exit 1
fi
if [ -s "$output_file" ]; then
  printf '%s\n' 'Successful Spring facet check unexpectedly produced diagnostics.' >&2
  exit 1
fi
