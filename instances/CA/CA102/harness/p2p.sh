#!/usr/bin/env bash
set -euo pipefail
config=/etc/nginx/conf.d/default.conf
nginx -V >/tmp/ca102-nginx-version.log 2>&1
for name in example.domain ipv4.example.domain ipv6.example.domain; do
  if ! grep -F "server_name $name;" "$config" >/dev/null; then
    echo "missing server name: $name" >&2
    exit 1
  fi
done
if ! grep -F "listen [::]:80" "$config" >/dev/null; then
  echo "missing IPv6 listener" >&2
  exit 1
fi
if ! grep -F "listen 80" "$config" >/dev/null; then
  echo "missing IPv4 listener" >&2
  exit 1
fi
