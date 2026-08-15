#!/usr/bin/env bash
set -euo pipefail
config=/etc/mysql/conf.d/cb116.cnf
test -f "$config"
grep -Eq '^\[mysqld\]$' "$config"
grep -Eq '^bind-address[[:space:]]*=' "$config"
test "$(grep -Ec '^[[:space:]]*bind-address[[:space:]]*=' "$config")" -eq 1
! grep -Eq '^[[:space:]]*(skip-networking|skip-grant-tables)[[:space:]]*($|=)' "$config"
