#!/usr/bin/env bash
set -euo pipefail
log=/tmp/ca102-f2p-nginx-test.log
set +e
nginx -t >"$log" 2>&1
status=$?
set -e
cat "$log"
if [ "$status" -ne 0 ]; then
  exit 1
fi
