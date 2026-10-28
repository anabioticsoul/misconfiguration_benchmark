#!/usr/bin/env bash
set -euo pipefail
command -v nginx >/dev/null
[ -x /usr/sbin/nginx ]
[ -f /etc/nginx/sites-enabled/default ]
grep -F 'listen 80 default_server;' /etc/nginx/sites-enabled/default >/dev/null
nginx -V >/dev/null 2>&1
