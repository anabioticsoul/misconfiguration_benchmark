#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apache2 curl php-cli ca-certificates
rm -rf /var/lib/apt/lists/*
a2enmod proxy proxy_http
a2dissite 000-default
a2ensite cd163
install -d -o www-data -g www-data /var/www/html
install -d /var/log/cd163
rm -f /var/www/html/index.html
apache2ctl configtest
