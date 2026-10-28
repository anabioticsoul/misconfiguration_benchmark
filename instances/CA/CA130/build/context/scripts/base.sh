#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apache2 openssl ca-certificates
rm -rf /var/lib/apt/lists/*
mkdir -p /etc/apache2/ssl
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout /etc/apache2/ssl/ca130.key \
  -out /etc/apache2/ssl/ca130.crt \
  -subj '/CN=ca130.example.test' \
  -addext 'subjectAltName=DNS:ca130.example.test'
chmod 600 /etc/apache2/ssl/ca130.key
cat > /etc/apache2/sites-available/ca130.conf <<'EOF'
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName ca130.example.test
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/ca130.crt
    SSLCertificateKeyFile /etc/apache2/ssl/ca130.key
</VirtualHost>
</IfModule>
EOF
a2enmod ssl
a2ensite ca130.conf
printf 'CA130 Apache fixture\n' > /var/www/html/index.html
