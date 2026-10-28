#!/usr/bin/env bash
set -euo pipefail
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
mysqld --user=mysql --skip-log-error &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 60); do
  if mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
    break
  fi
  kill -0 "$pid" 2>/dev/null || { wait "$pid" || true; exit 1; }
  sleep 1
done
mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot <<'SQL'
CREATE USER IF NOT EXISTS 'ca151'@'%' IDENTIFIED BY 'ca151';
GRANT ALL PRIVILEGES ON *.* TO 'ca151'@'%';
FLUSH PRIVILEGES;
SQL
mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock shutdown
wait "$pid" || true
trap - EXIT
