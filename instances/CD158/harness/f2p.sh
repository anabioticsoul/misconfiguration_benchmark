#!/usr/bin/env bash
set -euo pipefail
command -v nginx >/dev/null
[ ! -e /etc/nginx/sites-enabled/default~ ]
nginx -t
nginx -s stop >/dev/null 2>&1 || true
nginx
trap 'nginx -s stop >/dev/null 2>&1 || true' EXIT
if command -v wget >/dev/null; then
  wget -q -O - http://127.0.0.1/ | grep -F 'Welcome to nginx' >/dev/null
else
  test -s /var/www/index.html
fi
