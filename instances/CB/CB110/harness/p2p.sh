#!/usr/bin/env bash
set -euo pipefail
nginx -t >/dev/null 2>&1
config="$(cat /etc/nginx/conf.d/default.conf)"
printf '%s\n' "$config" | grep -F 'location = /jenkins' >/dev/null
printf '%s\n' "$config" | grep -F 'proxy_set_header Host $host;' >/dev/null
