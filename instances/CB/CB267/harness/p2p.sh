#!/usr/bin/env bash
set -euo pipefail

set -a
. /etc/environment
set +a

test -f /etc/environment
php -r 'if (PHP_SAPI !== "cli" || 2 + 2 !== 4) { exit(1); }'
