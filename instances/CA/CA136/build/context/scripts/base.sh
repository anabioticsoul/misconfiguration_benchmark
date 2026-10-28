#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends php8.2-fpm curl ca-certificates
rm -rf /var/lib/apt/lists/*
mkdir -p /run/php /var/log/nginx
sed -i 's#^listen = .*#listen = 127.0.0.1:9000#' /etc/php/8.2/fpm/pool.d/www.conf
sed -i 's#^;clear_env = no#clear_env = no#' /etc/php/8.2/fpm/pool.d/www.conf
nginx -t
touch /opt/ca136-ready
