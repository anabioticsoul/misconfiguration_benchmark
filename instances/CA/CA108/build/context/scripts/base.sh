#!/usr/bin/env bash
set -euo pipefail
apt-get update
apt-get install -y --no-install-recommends python3 openssl procps curl
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj /CN=localhost -keyout /etc/nginx/upstream.key -out /etc/nginx/upstream.crt >/dev/null 2>&1
chmod 755 /usr/local/bin/upstream.py
cat >/etc/supervisord.conf <<'EOF'
[supervisord]
nodaemon=true
[program:upstream]
command=/usr/local/bin/upstream.py
autostart=true
autorestart=true
[program:nginx]
command=nginx -g 'daemon off;'
autostart=true
autorestart=true
EOF
