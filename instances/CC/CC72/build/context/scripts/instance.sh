#!/usr/bin/env bash
set -euo pipefail
cd /opt/rector-demo
composer dump-autoload --no-interaction --no-scripts >/dev/null
