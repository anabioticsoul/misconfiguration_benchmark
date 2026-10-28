#!/usr/bin/env bash
set -euo pipefail
log="${TMPDIR:-/tmp}/ca56-f2p.$$.log"
set +e
nginx -t >"$log" 2>&1
status=$?
set -e
cat "$log"
if [ "$status" -ne 0 ]; then
  rm -f "$log"
  echo "nginx -t failed unexpectedly: $status" >&2
  exit 1
fi
if grep -F 'duplicate MIME type "text/html"' "$log" >/dev/null; then
  rm -f "$log"
  echo 'duplicate MIME warning remains' >&2
  exit 1
fi
rm -f "$log"
