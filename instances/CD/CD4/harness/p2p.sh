#!/usr/bin/env bash
set -euo pipefail

result=$(mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='cd4db' AND table_name='payload';")
case "$result" in
  1) ;;
  *) echo "prepared payload table is unavailable" >&2; exit 1 ;;
esac
count=$(mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -NBe 'SELECT COUNT(*) FROM cd4db.payload;')
case "$count" in
  ''|*[!0-9]*) echo "payload table did not return a numeric count" >&2; exit 1 ;;
esac
