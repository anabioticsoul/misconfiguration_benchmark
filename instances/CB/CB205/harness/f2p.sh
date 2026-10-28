#!/usr/bin/env bash
set -euo pipefail
logdir="/tmp/cb205-f2p"
rm -rf "$logdir"; mkdir -p "$logdir"
cleanup() { nginx -s stop >/dev/null 2>&1 || true; }
trap cleanup EXIT
nginx -t >"$logdir/nginx.log" 2>&1
nginx >>"$logdir/nginx.log" 2>&1
apache2ctl -DFOREGROUND >"$logdir/apache.log" 2>&1 &
apid=$!
for _ in $(seq 1 30); do
  if ! kill -0 "$apid" 2>/dev/null; then
    cat "$logdir/apache.log" >&2
    exit 1
  fi
  if curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! kill -0 "$apid" 2>/dev/null; then cat "$logdir/apache.log" >&2; exit 1; fi
curl -fsS http://127.0.0.1/ >/dev/null
kill "$apid" 2>/dev/null || true
wait "$apid" 2>/dev/null || true
