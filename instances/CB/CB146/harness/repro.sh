#!/usr/bin/env bash
set -euo pipefail
socket=/var/run/mysqld/mysqld.sock
if [ ! -d /var/lib/mysql/mysql ]; then
  mysqld --initialize-insecure --datadir=/var/lib/mysql >/tmp/mysql-init.log 2>&1
fi
mysqld --user=mysql --datadir=/var/lib/mysql --socket="$socket" --skip-networking >/tmp/mysql.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 60); do mysqladmin --socket="$socket" ping >/dev/null 2>&1 && break; sleep 1; done
mysqladmin --socket="$socket" ping >/dev/null 2>&1
mysql --socket="$socket" -uroot -e "CREATE DATABASE IF NOT EXISTS homestead; CREATE USER IF NOT EXISTS 'homestead'@'localhost' IDENTIFIED BY 'secret'; GRANT ALL ON homestead.* TO 'homestead'@'localhost'; FLUSH PRIVILEGES;"
set +e
output=$(/opt/laravel/artisan migrate 2>&1)
status=$?
set -e
printf '%s\n' "$output" >&2
[ "$status" -ne 0 ]
printf '%s' "$output" | grep -F "Can't connect to local MySQL server through socket" >/dev/null
