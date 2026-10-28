#!/usr/bin/env bash
set -euo pipefail
rm -f /etc/nginx/conf.d/default.conf.bak
chown -R www-data:www-data /var/www/html
nginx -t
