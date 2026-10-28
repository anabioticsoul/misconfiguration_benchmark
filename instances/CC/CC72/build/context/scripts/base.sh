#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git php-cli php-xml php-mbstring unzip
php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm -f /tmp/composer-setup.php
cd /opt/rector-demo
composer install --no-interaction --no-progress --prefer-dist
chmod +x vendor/bin/rector
rm -rf /var/lib/apt/lists/*
