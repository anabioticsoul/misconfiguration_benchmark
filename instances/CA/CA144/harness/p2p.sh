#!/usr/bin/env bash
set -euo pipefail

test -s /etc/nginx/conf.d/default.conf
nginx -t >/dev/null
# Preserve the declared application response while the listen port is repaired.
grep -q 'return 200 "nginx-ok\\n"' /etc/nginx/conf.d/default.conf
