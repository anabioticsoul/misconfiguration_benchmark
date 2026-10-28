#!/usr/bin/env bash
set -euo pipefail
url='http://127.0.0.1/jenkins'
set +e
output="$(curl --fail --silent --show-error "$url" 2>&1)"
status=$?
set -e
[ "$status" -ne 0 ]
printf '%s\n' "$output" | grep -F 'The requested URL returned error: 502' >/dev/null
printf 'Observed expected reverse-proxy failure (HTTP 502).\n'
