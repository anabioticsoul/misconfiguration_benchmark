#!/usr/bin/env bash
set -euo pipefail
nginx -t
[ -s /etc/nginx/ssl/server.crt ]
[ -s /etc/nginx/ssl/server.key ]
grep -Fq 'server_name localhost;' /etc/nginx/conf.d/default.conf
