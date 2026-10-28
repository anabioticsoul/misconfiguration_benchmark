#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apache2 nginx curl
rm -rf /var/lib/apt/lists/*

cat > /etc/apache2/ports.conf <<'EOF'
Listen 8080

<IfModule ssl_module>
    Listen 443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
EOF

rm -f /etc/apache2/sites-enabled/*
cat > /etc/apache2/sites-available/mysite.conf <<'EOF'
<VirtualHost *:8080>
    ServerName myproject
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF
ln -s ../sites-available/mysite.conf /etc/apache2/sites-enabled/mysite.conf
a2enmod proxy proxy_http >/dev/null
printf 'apache-ok\n' > /var/www/html/index.html

rm -f /etc/nginx/sites-enabled/*
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location = /health {
        default_type text/plain;
        return 200 "nginx-ok\n";
    }

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF
ln -s ../sites-available/default /etc/nginx/sites-enabled/default
nginx -t
apache2ctl -t
