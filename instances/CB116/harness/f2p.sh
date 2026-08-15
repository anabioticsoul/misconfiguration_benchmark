#!/usr/bin/env bash
set -euo pipefail
output="$(mktemp)"
trap 'if test -n "${pid:-}"; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; rm -f "$output"' EXIT
mysqld --user=mysql --console --skip-grant-tables >"$output" 2>&1 &
pid=$!
for _ in $(seq 1 30); do
  if mysqladmin --protocol=tcp --host=127.0.0.1 --port=3306 ping >/dev/null 2>&1; then
    grep -Fq "ready for connections" "$output"
    exit 0
  fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 1
done
cat "$output"
exit 1
