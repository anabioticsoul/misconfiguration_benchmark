#!/usr/bin/env bash
set -euo pipefail

apachectl configtest
[ -f /etc/apache2/ports.conf ]
[ -f /etc/apache2/sites-enabled/000-default.conf ]
