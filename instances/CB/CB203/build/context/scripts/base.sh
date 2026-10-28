#!/usr/bin/env bash
set -euo pipefail
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl openssl
rm -rf /var/lib/apt/lists/*
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout /etc/nginx/test.key -out /etc/nginx/test.crt \
  -subj '/CN=app1.internal.example.com' 2>/dev/null
chmod 600 /etc/nginx/test.key
nginx -t
