#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends nginx apache2 curl ca-certificates
rm -rf /var/lib/apt/lists/*
printf 'Listen 8080\n\n<IfModule ssl_module>\n\tListen 443\n</IfModule>\n\n<IfModule mod_gnutls.c>\n\tListen 443\n</IfModule>\n' > /etc/apache2/ports.conf
sed -i 's#<VirtualHost \*:80>#<VirtualHost *:8080>#' /etc/apache2/sites-available/000-default.conf
rm -f /var/run/nginx.pid /var/run/apache2/apache2.pid
