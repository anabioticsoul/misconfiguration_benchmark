#!/usr/bin/env bash
set -euo pipefail

pool=/etc/php/7.4/fpm/pool.d/www.conf
/usr/local/php7.4/sbin/php-fpm -t -y /etc/php/7.4/fpm/php-fpm.conf
apachectl -t
/usr/local/php7.4/bin/php -r 'if (PHP_SAPI !== "cli") { exit(1); } echo "php-cli-ok\\n";'
grep -Fqx 'user = shell_user' "$pool"
grep -Fqx 'group = shell_user' "$pool"
grep -Fqx 'listen = /run/php/php7.4-fpm.sock' "$pool"
passwd_entry=$(getent passwd shell_user)
[ -n "$passwd_entry" ]
