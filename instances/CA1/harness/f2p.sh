#!/usr/bin/env bash
set -euo pipefail
rm -f /tmp/ca1-mysqld.sock /tmp/ca1-mysqld.pid /tmp/ca1-f2p.log
mysqld --user=mysql --datadir=/var/lib/mysql --socket=/tmp/ca1-mysqld.sock --pid-file=/tmp/ca1-mysqld.pid >/tmp/ca1-f2p.log 2>&1 &
server_pid=$!
cleanup() {
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT
for _ in $(seq 1 30); do
  if mysqladmin --protocol=socket --socket=/tmp/ca1-mysqld.sock ping >/dev/null 2>&1; then
    mysql --protocol=socket --socket=/tmp/ca1-mysqld.sock -uroot -e 'SELECT 1;' >/dev/null
    exit 0
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat /tmp/ca1-f2p.log >&2
    exit 1
  fi
  sleep 1
done
cat /tmp/ca1-f2p.log >&2
exit 1
