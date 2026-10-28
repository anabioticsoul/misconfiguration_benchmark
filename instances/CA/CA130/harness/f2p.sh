#!/usr/bin/env bash
set -euo pipefail
apache2ctl configtest
apache2ctl -k start
trap 'apache2ctl -k stop >/dev/null 2>&1 || true' EXIT
for _ in $(seq 1 30); do
  if (echo >/dev/tcp/127.0.0.1/443) >/dev/null 2>&1; then exit 0; fi
  if ! kill -0 "$(cat /var/run/apache2/apache2.pid 2>/dev/null)" 2>/dev/null; then exit 1; fi
  sleep 1
done
exit 1
