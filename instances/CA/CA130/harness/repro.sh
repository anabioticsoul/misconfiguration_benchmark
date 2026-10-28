#!/usr/bin/env bash
set -euo pipefail
output="$(apache2ctl configtest 2>&1)" && status=0 || status=$?
if [ "$status" -eq 0 ]; then
  printf '%s\n' "$output" >&2
  echo 'expected Apache configuration test failure' >&2
  exit 1
fi
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -Eiq 'missing-ca130\.crt|does not exist|cannot load certificate|No such file'
