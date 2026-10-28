#!/usr/bin/env bash
set -euo pipefail
[ "$(command -v php)" = "/usr/bin/php" ]
php --version >/dev/null
php -i | grep -F 'Loaded Configuration File => /etc/php/8.1/cli/php.ini' >/dev/null
[ "$(php -r 'echo 2 + 2;')" = "4" ]
