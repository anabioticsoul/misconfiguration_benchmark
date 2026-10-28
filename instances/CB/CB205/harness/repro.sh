#!/usr/bin/env bash
set -euo pipefail
logdir="/tmp/cb205-repro"
rm -rf "$logdir"; mkdir -p "$logdir"
cleanup() { nginx -s stop >/dev/null 2>&1 || true; }
trap cleanup EXIT
nginx -t >"$logdir/nginx.log" 2>&1
nginx >>"$logdir/nginx.log" 2>&1
set +e
apache2ctl -DFOREGROUND >"$logdir/apache.log" 2>&1
status=$?
set -e
cat "$logdir/apache.log"
if [ "$status" -eq 0 ]; then
  echo 'Apache unexpectedly started despite the occupied listener' >&2
  exit 1
fi
grep -F 'Address already in use' "$logdir/apache.log"
