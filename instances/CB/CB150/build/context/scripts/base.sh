#!/usr/bin/env bash
set -euo pipefail
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl php-fpm
rm -rf /var/lib/apt/lists/*
mkdir -p /tmp/nginx-fastcgi /var/www/html
chown -R nginx:nginx /tmp/nginx-fastcgi /var/www/html
sed -i 's|^listen = .*|listen = 127.0.0.1:9000|' /etc/php/8.2/fpm/pool.d/www.conf
