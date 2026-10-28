#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cb128-repro.log
rm -f "$log" /srv/mysql/sockets/mysql-myDB.sock /srv/mysql/pids/mysqld-myDB.pid
set +e
mysqld --no-defaults --user=mysql --datadir=/srv/mysql/myDB --socket=/srv/mysql/sockets/mysql-myDB.sock --pid-file=/srv/mysql/pids/mysqld-myDB.pid --port=3700 --skip-networking >"$log" 2>&1
status=$?
set -e
output=$(cat "$log")
printf '%s\n' "$output"
test "$status" -ne 0
grep -F 'Could not create unix socket lock file' <<EOF
$output
EOF
