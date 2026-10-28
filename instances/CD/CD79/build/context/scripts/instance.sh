#!/usr/bin/env bash
set -euo pipefail
sed -i 's/Require all granted/Require all denied/' /etc/apache2/sites-available/000-default.conf
apache2ctl configtest
