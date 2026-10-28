#!/usr/bin/env bash
set -euo pipefail
config=$(cat /etc/nginx/conf.d/ca56.conf)
printf '%s\n' "$config" | grep -F 'gzip_types ' >/dev/null
nginx -t >/tmp/ca56-p2p.$$.log 2>&1
cat /tmp/ca56-p2p.$$.log
rm -f /tmp/ca56-p2p.$$.log
