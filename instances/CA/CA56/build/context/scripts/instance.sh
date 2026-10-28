#!/usr/bin/env bash
set -euo pipefail
chmod 0644 /etc/nginx/conf.d/ca56.conf
nginx -t >/dev/null 2>/dev/null || true
