#!/usr/bin/env bash
set -euo pipefail

set +e
output="$(php /opt/ca115/app.php 2>&1)"
status=$?
set -e

printf '%s\n' "$output"
[ "$status" -eq 0 ]
if grep -Fq 'Deprecated: strlen(): Passing null to parameter' <<<"$output"; then
  exit 1
fi
grep -Fq 'Warning: Undefined variable' <<<"$output"
