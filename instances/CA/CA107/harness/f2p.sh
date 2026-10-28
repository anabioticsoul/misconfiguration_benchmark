#!/usr/bin/env bash
set -euo pipefail
out="$(nginx -T 2>&1)"
printf '%s\n' "$out" | grep -F 'syntax is ok' >/dev/null
printf '%s\n' "$out" | grep -F 'limit_req_zone $http_CLIENT_KEY zone=newzone:10m rate=10r/m;' >/dev/null
if printf '%s\n' "$out" | grep -F 'rate=1r/m;' >/dev/null; then
  exit 1
fi
