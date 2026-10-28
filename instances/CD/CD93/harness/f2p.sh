#!/usr/bin/env bash
set -euo pipefail
socket=/tmp/cd93-f2p.sock
datadir=/tmp/cd93-f2p-data
log=/tmp/cd93-f2p.log
rm -rf "$datadir" "$socket" "$log"
mkdir -p "$datadir"
chown -R mysql:mysql "$datadir"
mysqld --defaults-extra-file=/etc/mysql/conf.d/fault.cnf --initialize-insecure --datadir="$datadir" --user=mysql >"$log" 2>&1
mysqld --defaults-extra-file=/etc/mysql/conf.d/fault.cnf --datadir="$datadir" --user=mysql --skip-networking --socket="$socket" >"$log" 2>&1 &
pid=$!
cleanup() { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
trap cleanup EXIT
for _ in $(seq 1 30); do mysqladmin --no-defaults --socket="$socket" ping >/dev/null 2>&1 && break; sleep 1; done
if ! mysqladmin --no-defaults --socket="$socket" ping >/dev/null 2>&1; then cat "$log"; exit 1; fi
mysql --no-defaults --socket="$socket" -NBe "SELECT @@innodb_file_per_table" | grep -Fx '1'
