#!/usr/bin/env bash
set -euo pipefail

log=/tmp/cd4-f2p.log
set +e
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot cd4db < /opt/cd4/dump.sql >"$log" 2>&1
status=$?
set -e
cat "$log"
if [ "$status" -ne 0 ]; then
  echo "large dump import failed" >&2
  exit 1
fi
count=$(mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -NBe 'SELECT COUNT(*) FROM cd4db.payload;')
case "$count" in
  1) ;;
  *) echo "expected one imported payload row, got: $count" >&2; exit 1 ;;
esac
