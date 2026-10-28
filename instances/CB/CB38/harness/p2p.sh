#!/usr/bin/env bash
set -euo pipefail

health=http://127.0.0.1/health
static_root=/home/ubuntu/virtualenv/myapp/myapp/homelaunch/static

response=$(curl -sS --fail --max-time 5 "$health")
[ "$response" = "healthy" ]
[ -d "$static_root" ]
[ "$(stat -c '%a' "$static_root")" = "700" ]
[ "$(stat -c '%a' "$static_root/img/templated/home/img.png")" = "600" ]
nginx -t
