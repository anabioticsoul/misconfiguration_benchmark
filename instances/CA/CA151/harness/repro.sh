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
host_ip="$(hostname -I | awk '{print $1}')"
set +e
output="$(mysql --connect-timeout=3 -h "$host_ip" -P 3306 -u ca151 -pca151 -e 'SELECT 1' 2>&1)"
status=$?
set -e
printf '%s\n' "$output"
test "$status" -ne 0
grep -F 'ERROR 2003' <<<"$output"
grep -F '(111)' <<<"$output"
