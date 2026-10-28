#!/usr/bin/env bash
set -euo pipefail
nginx -t
[ -f /etc/nginx/nginx.conf ]
