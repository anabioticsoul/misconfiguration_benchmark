#!/usr/bin/env bash
set -euo pipefail

set +e
output="$(php /opt/ca115/app.php 2>&1)"
status=$?
set -e

printf '%s\n' "$output"
[ "$status" -ne 0 ] || exit 1
grep -Fq 'Deprecated: strlen(): Passing null to parameter' <<<"$output"
grep -Fq 'Warning: Undefined variable' <<<"$output"
