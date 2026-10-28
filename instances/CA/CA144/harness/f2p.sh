#!/usr/bin/env bash
set -euo pipefail

nginx -t >/dev/null
nginx -s reload >/dev/null 2>&1 || nginx >/dev/null 2>&1
for _ in $(seq 1 50); do
  if bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080' 2>/dev/null; then
    printf 'GET / HTTP/1.0\r\nHost: blog.project.com\r\n\r\n' >&3
    response="$(cat <&3)"
    exec 3>&-
    grep -q "200 OK" <<<"$response"
    grep -q "nginx-ok" <<<"$response"
    exit 0
  fi
  sleep 0.1
done
echo "Nginx is not reachable on backend port 8080" >&2
exit 1
