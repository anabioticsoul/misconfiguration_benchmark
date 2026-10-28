#!/usr/bin/env bash
set -euo pipefail

set -a
. /etc/environment
set +a

set +e
output="$(php -d display_errors=1 -r 'curl_init();' 2>&1)"
status=$?
set -e
printf '%s\n' "$output"

if [ "$status" -eq 0 ]; then
  echo "curl_init unexpectedly succeeded before repair" >&2
  exit 1
fi
case "$output" in
  *"Call to undefined function curl_init()"*) ;;
  *)
    echo "Expected undefined curl_init symptom was not observed" >&2
    exit 1
    ;;
esac
