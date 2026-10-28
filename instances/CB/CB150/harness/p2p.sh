#!/usr/bin/env bash
set -euo pipefail
nginx -t -c /etc/nginx/nginx.conf >/tmp/cb150-p2p-test.log 2>&1
config=$(cat /etc/nginx/conf.d/fastcgi.conf)
printf '%s' "$config" | grep -F 'fastcgi_pass 127.0.0.1:9000;' >/dev/null
printf '%s' "$config" | grep -F 'fastcgi_temp_path' >/dev/null
