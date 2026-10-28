#!/usr/bin/env bash
set -euo pipefail

php -r 'if (PHP_SAPI !== "cli") { exit(1); } echo "PHP CLI available\n";'

set +e
output="$(php /opt/ca115/app.php 2>&1)"
status=$?
set -e

printf '%s\n' "$output"
grep -Fq 'Warning: Undefined variable' <<<"$output"
test -f /opt/ca115/app.php
