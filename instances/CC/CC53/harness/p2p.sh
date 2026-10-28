#!/usr/bin/env bash
set -euo pipefail
test -f /etc/apache2/.htpasswd
test -f /var/www/html/writing/.htaccess
grep -F 'AuthType Basic' /var/www/html/writing/.htaccess >/dev/null
grep -F 'Require valid-user' /var/www/html/writing/.htaccess >/dev/null
