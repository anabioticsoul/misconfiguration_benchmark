#!/usr/bin/env bash
set -euo pipefail
mysqld --user=mysql --skip-log-error >/tmp/ca151-mysqld.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 60); do
  mysqladmin --protocol=socket ping >/dev/null 2>&1 && break
  kill -0 "$pid" 2>/dev/null || { wait "$pid" || true; exit 1; }
  sleep 1
done
mysql --protocol=socket -u ca151 -pca151 -e 'SELECT 1' | grep -F '1'
