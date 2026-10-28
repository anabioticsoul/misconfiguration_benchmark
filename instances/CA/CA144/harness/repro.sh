#!/usr/bin/env bash
set -euo pipefail

nginx -t >/tmp/nginx-test.out 2>&1
nginx -s reload >/tmp/nginx-reload.out 2>&1 || nginx >/tmp/nginx-start.out 2>&1
rm -f /tmp/backend.err
for _ in $(seq 1 50); do
  if bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080' 2>/tmp/backend.err; then
    echo "unexpectedly connected to 8080" >&2
    exit 1
  fi
  if grep -qi "connection refused" /tmp/backend.err; then
    echo "Connection refused: Nginx is not listening on Traefik backend port 8080"
    exit 0
  fi
  sleep 0.1
done
cat /tmp/backend.err >&2
exit 1
