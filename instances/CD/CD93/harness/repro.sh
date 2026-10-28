#!/usr/bin/env bash
set -euo pipefail

socket=/tmp/cd93-repro.sock
datadir=/tmp/cd93-repro-data
log=/tmp/cd93-repro.log
rm -rf "$datadir" "$socket" "$log"
mkdir -p "$datadir"
chown -R mysql:mysql "$datadir"
mysqld --defaults-extra-file=/etc/mysql/conf.d/fault.cnf --initialize-insecure --datadir="$datadir" --user=mysql >"$log" 2>&1
mysqld --defaults-extra-file=/etc/mysql/conf.d/fault.cnf --datadir="$datadir" --user=mysql --skip-networking --socket="$socket" >"$log" 2>&1 &
pid=$!
cleanup() { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
trap cleanup EXIT
for _ in $(seq 1 30); do
  if mysqladmin --no-defaults --socket="$socket" ping >/dev/null 2>&1; then break; fi
  sleep 1
done
if ! mysqladmin --no-defaults --socket="$socket" ping >/dev/null 2>&1; then cat "$log"; exit 1; fi
value=$(mysql --no-defaults --socket="$socket" -NBe "SHOW GLOBAL VARIABLES LIKE 'innodb_file_per_table'" | awk '{print $2}')
mysql --no-defaults --socket="$socket" -e "CREATE DATABASE cd93_repro; CREATE TABLE cd93_repro.t (id INT PRIMARY KEY) ENGINE=InnoDB; DROP DATABASE cd93_repro;"
if [ "$value" != "OFF" ]; then
  printf '%s\n' "unexpected innodb_file_per_table value: $value" >&2
  cat "$log"
  exit 1
fi
printf '%s\n' "innodb_file_per_table is OFF" >&2
