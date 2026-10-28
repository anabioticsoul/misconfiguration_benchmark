#!/usr/bin/env bash
set -euo pipefail

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT
set +e
/usr/local/bin/intellij-spring-check >"$output_file" 2>&1
status=$?
set -e
cat "$output_file"

if [ "$status" -eq 0 ]; then
  printf '%s\n' 'Expected the unmapped Spring configuration check to fail.' >&2
  exit 1
fi
grep -Fq 'Unmapped Spring configuration files found.' "$output_file"
grep -Fq 'Please configure/setup Spring facet for modules' "$output_file"
