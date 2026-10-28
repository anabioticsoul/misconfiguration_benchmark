#!/usr/bin/env bash
set -euo pipefail
chown -R www-data:www-data /var/www/example.com
chmod 755 /var/www/example.com
chmod 644 /var/www/example.com/*.php
