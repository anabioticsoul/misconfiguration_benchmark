#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cc53-f2p.log
set +e
apache2ctl -t > /tmp/cc53-f2p.out 2>"$log"
status=$?
set -e
cat "$log"
if [ "$status" -ne 0 ]; then cat /tmp/cc53-f2p.out; exit 1; fi
rm -f /var/run/apache2/apache2.pid
apache2ctl -k start > /tmp/cc53-start.out 2>"$log" || { cat "$log"; exit 1; }
trap 'apache2ctl -k stop >/dev/null 2>&1 || true' EXIT
for i in $(seq 1 30); do
  code=$(curl -sS -o /tmp/cc53-body -w '%{http_code}' -u benchmark:secret http://127.0.0.1/writing/ 2>>"$log" || true)
  [ "$code" = 200 ] && grep -F 'protected apache content' /tmp/cc53-body >/dev/null && exit 0
  sleep 1
done
cat "$log"; exit 1
