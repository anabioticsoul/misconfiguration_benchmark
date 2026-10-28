#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cd84-repro.log
rm -f "$log" /var/mysql/mysql.sock /var/lib/mysql/mysql.sock
set +e
mysqld --defaults-file=/etc/my.cnf --user=mysql --datadir=/var/lib/mysql --skip-networking >"$log" 2>&1
status=$?
set -e
cat "$log"
[ "$status" -ne 0 ]
grep -F 'Unable to setup unix socket lock file' "$log" >/dev/null
echo 'CD84 reproduction confirmed: mysqld cannot create the configured socket.'
