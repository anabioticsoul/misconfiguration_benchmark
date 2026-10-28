#!/usr/bin/env bash
set -euo pipefail
mkdir -p /etc/php/8.1/cli
cat > /etc/php/8.1/cli/php.ini <<'INI'
[PHP]
html_errors = On
INI
