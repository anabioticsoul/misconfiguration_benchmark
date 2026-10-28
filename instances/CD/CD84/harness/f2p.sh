#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cd84-f2p.log
rm -f "$log" /var/mysql/mysql.sock /var/lib/mysql/mysql.sock
mysqld --defaults-file=/etc/my.cnf --user=mysql --datadir=/var/lib/mysql --skip-networking >"$log" 2>&1 &
pid=$!
cleanup() { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
trap cleanup EXIT
ready=0
for _ in $(seq 1 60); do
  if mysqladmin --protocol=socket --socket=/var/lib/mysql/mysql.sock ping >/tmp/cd84-ping.out 2>&1; then ready=1; break; fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  cat "$log"
  cat /tmp/cd84-ping.out
  exit 1
fi
mysqladmin --protocol=socket --socket=/var/lib/mysql/mysql.sock ping
