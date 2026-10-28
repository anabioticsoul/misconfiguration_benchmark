#!/usr/bin/env bash
set -euo pipefail
body_file="${TMPDIR:-/tmp}/cd163-repro-body.$$"
err_file="${TMPDIR:-/tmp}/cd163-repro-err.$$"
cleanup() { rm -f "$body_file" "$err_file"; }
trap cleanup EXIT
status="$(curl -sS -o "$body_file" -w '%{http_code}' http://127.0.0.1/fault.php 2>"$err_file")"
if [ "$status" != "500" ]; then
  echo "expected HTTP 500, got $status" >&2
  cat "$err_file" >&2
  exit 1
fi
if grep -Fq 'CD163 PHP detailed failure:' "$body_file"; then
  echo "unexpectedly received detailed PHP response" >&2
  exit 1
fi
if ! grep -Fq 'The page cannot be displayed because an internal server error has occurred.' "$body_file"; then
  echo "generic server error response was not observed" >&2
  cat "$body_file" >&2
  exit 1
fi
set +e
curl -fsS -o "$body_file" http://127.0.0.1/fault.php 2>"$err_file"
curl_rc=$?
set -e
if [ "$curl_rc" -eq 0 ]; then
  echo "curl unexpectedly accepted the failing request" >&2
  exit 1
fi
if ! grep -Fq '500' "$err_file"; then
  cat "$err_file" >&2
  exit 1
fi
printf '%s\n' 'CD163 reproduction observed generic HTTP 500 handling.'
