#!/usr/bin/env bash
set -euo pipefail

test -x /usr/local/bin/ca139-export
test -f /usr/local/lib/ca139/export.php
test -f /var/www/html/config/etc/php7/conf.d/php.ini
grep -F 'memory_limit = 1024M' /var/www/html/config/etc/php7/conf.d/php.ini >/dev/null

php_output="$(/usr/bin/php -r 'echo "php-ok\n";')"
if [[ "$php_output" != "php-ok" ]]; then
    echo "PHP CLI invariant failed" >&2
    exit 1
fi
