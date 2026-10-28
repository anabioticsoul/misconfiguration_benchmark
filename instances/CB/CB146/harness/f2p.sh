#!/usr/bin/env bash
set -euo pipefail
socket=/var/run/mysqld/mysqld.sock
if ! mysqladmin --socket="$socket" ping >/dev/null 2>&1; then
  mysqld --user=mysql --datadir=/var/lib/mysql --socket="$socket" --skip-networking >/tmp/mysql.log 2>&1 &
  pid=$!
  trap 'kill "$pid" 2>/dev/null || true' EXIT
  for _ in $(seq 1 60); do mysqladmin --socket="$socket" ping >/dev/null 2>&1 && break; sleep 1; done
fi
mysql --socket="$socket" -uroot -e "CREATE DATABASE IF NOT EXISTS homestead; CREATE USER IF NOT EXISTS 'homestead'@'localhost' IDENTIFIED BY 'secret'; GRANT ALL ON homestead.* TO 'homestead'@'localhost'; FLUSH PRIVILEGES;"
output=$(/opt/laravel/artisan migrate 2>&1)
printf '%s\n' "$output"
mysql --socket="$socket" -uroot -e 'SELECT 1' >/dev/null
