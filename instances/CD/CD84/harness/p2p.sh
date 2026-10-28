#!/usr/bin/env bash
set -euo pipefail
[ "$(awk -F= '$1=="port" {gsub(/[[:space:]]/, "", $2); print $2; exit}' /etc/my.cnf)" = "3306" ]
[ "$(id -u mysql)" -ne 0 ]
