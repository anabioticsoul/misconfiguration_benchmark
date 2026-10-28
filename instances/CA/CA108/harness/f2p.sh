#!/usr/bin/env bash
set -euo pipefail
/usr/local/bin/upstream.py >/tmp/upstream.log 2>&1 & upstream_pid=$!
nginx -t >/tmp/nginx-test.log 2>&1
nginx -g 'daemon off;' >/tmp/nginx.log 2>&1 & nginx_pid=$!
cleanup() { kill "$nginx_pid" "$upstream_pid" 2>/dev/null || true; }
trap cleanup EXIT
for _ in $(seq 1 50); do
  if curl -fsS http://127.0.0.1:8081/127.0.0.1:8443/hello >/tmp/probe 2>/dev/null; then break; fi
done
grep -Fx 'upstream HTTPS content' /tmp/probe
