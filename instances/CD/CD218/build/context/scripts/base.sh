#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends php-cli php-xdebug ca-certificates
rm -rf /var/lib/apt/lists/*

install -d -m 0755 /etc/php/8.1/cli/conf.d
cat > /etc/php/8.1/cli/conf.d/99-xdebug.ini <<'EOF'
; Xdebug 3 debugger mode.
xdebug.mode=debug
EOF

php -m > /tmp/cd218-php-modules.txt
grep -i '^xdebug$' /tmp/cd218-php-modules.txt > /dev/null
rm -f /tmp/cd218-php-modules.txt
