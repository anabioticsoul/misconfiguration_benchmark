#!/usr/bin/env bash
set -euo pipefail
cat > /etc/nginx/sites-enabled/default~ <<'EOF'
server {
    listen 8080;
    root /var/www;
    index index.html index.htm index.php;
    location / { try_files $uri $uri/ =404; }
    fastcgi_pass unix:/var/run/php5-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
}
EOF
chmod 644 /etc/nginx/sites-enabled/default~
