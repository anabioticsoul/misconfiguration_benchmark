#!/usr/bin/env bash
set -euo pipefail
body_file="${TMPDIR:-/tmp}/cd163-f2p-body.$$"
cleanup() { rm -f "$body_file"; }
trap cleanup EXIT
status="$(curl -sS -o "$body_file" -w '%{http_code}' http://127.0.0.1/fault.php)"
if [ "$status" != "500" ]; then
  echo "expected intentional PHP failure to remain HTTP 500, got $status" >&2
  exit 1
fi
if ! grep -Fq 'CD163 PHP detailed failure:' "$body_file"; then
  echo "PHP diagnostic body is still hidden by the generic server response" >&2
  cat "$body_file" >&2
  exit 1
fi
if grep -Fq 'The page cannot be displayed because an internal server error has occurred.' "$body_file"; then
  echo "generic error replacement is still active" >&2
  exit 1
fi
printf '%s\n' 'CD163 repair restored the detailed PHP error response.'
