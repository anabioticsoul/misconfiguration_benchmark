#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cd79-apache.log
rm -f "$log"
apache2ctl -k start -DFOREGROUND >"$log" 2>&1 &
pid=$!
cleanup() { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
trap cleanup EXIT
for _ in $(seq 1 30); do
  if curl -sS -o /tmp/cd79-body -w '%{http_code}' http://127.0.0.1/ >/tmp/cd79-code 2>/dev/null; then
    code=$(cat /tmp/cd79-code)
    if [ "$code" = 403 ]; then exit 0; fi
  fi
  sleep 1
done
cat "$log"
printf 'expected Apache HTTP 403, got: '
cat /tmp/cd79-code 2>/dev/null || true
exit 1
