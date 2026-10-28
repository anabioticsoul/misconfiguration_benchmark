#!/usr/bin/env bash
set -euo pipefail
log="${TMPDIR:-/tmp}/ca56-repro.$$.log"
set +e
nginx -t >"$log" 2>&1
status=$?
set -e
cat "$log"
if ! grep -F 'duplicate MIME type "text/html"' "$log" >/dev/null; then
  rm -f "$log"
  echo 'expected duplicate MIME warning was not observed' >&2
  exit 1
fi
rm -f "$log"
# nginx reports this diagnostic as a warning, so configuration testing succeeds.
if [ "$status" -ne 0 ]; then
  echo "unexpected nginx -t exit code: $status" >&2
  exit 1
fi
