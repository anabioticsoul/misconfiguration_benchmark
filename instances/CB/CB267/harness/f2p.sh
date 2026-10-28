#!/usr/bin/env bash
set -euo pipefail

set -a
. /etc/environment
set +a

set +e
output="$(php -d display_errors=1 -r '$handle = curl_init(); if ($handle === false) { exit(2); } curl_close($handle);' 2>&1)"
status=$?
set -e
printf '%s\n' "$output"
if [ "$status" -ne 0 ]; then
  echo "PHP could not load cURL and create a handle" >&2
  exit 1
fi
