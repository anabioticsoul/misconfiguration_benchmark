#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cd79-f2p-apache.log
rm -f "$log"
apache2ctl -k start -DFOREGROUND >"$log" 2>&1 &
pid=$!
cleanup() { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
trap cleanup EXIT
for _ in $(seq 1 30); do
  code=$(curl -sS -o /tmp/cd79-f2p-body -w '%{http_code}' http://127.0.0.1/ 2>/dev/null || true)
  if [ "$code" = 200 ]; then
    grep -Fqx 'custom-root-ok' /tmp/cd79-f2p-body
    exit $?
  fi
  sleep 1
done
cat "$log"
printf 'expected HTTP 200, got %s\n' "$code"
exit 1
