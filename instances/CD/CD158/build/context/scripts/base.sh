#!/usr/bin/env bash
set -euo pipefail
mkdir -p /var/www /etc/nginx/sites-enabled
rm -f /etc/nginx/conf.d/default.conf
cat > /etc/nginx/conf.d/sites-enabled.conf <<'EOF'
include /etc/nginx/sites-enabled/*;
EOF
cat > /var/www/index.html <<'EOF'
<!doctype html>
<html><head><title>Welcome to nginx!</title></head><body><h1>Welcome to nginx!</h1></body></html>
EOF
cat > /etc/nginx/sites-enabled/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www;
    index index.html index.htm index.php;
    location / { try_files $uri $uri/ =404; }
}
EOF
nginx -t
