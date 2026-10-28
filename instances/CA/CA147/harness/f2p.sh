#!/usr/bin/env bash
set -euo pipefail
config=/etc/php/8.1/cli/php.ini
configured=$(awk -F= '/^[[:space:]]*html_errors[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print tolower($2); exit}' "$config")
effective=$(php -r 'echo ini_get("html_errors") ? "on" : "off";')
[ -n "$configured" ] && [ -n "$effective" ] && [ "$configured" = "$effective" ]
