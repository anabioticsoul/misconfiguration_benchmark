#!/usr/bin/env bash
set -euo pipefail

log=/tmp/cd4-repro.log
set +e
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot cd4db < /opt/cd4/dump.sql >"$log" 2>&1
status=$?
set -e
cat "$log"
if [ "$status" -eq 0 ]; then
  echo "expected the large import to fail" >&2
  exit 1
fi
if ! grep -F "Got a packet bigger than 'max_allowed_packet' bytes" "$log" >/dev/null; then
  echo "missing expected packet-size diagnostic" >&2
  exit 1
fi
if ! grep -F 'line 149351' "$log" >/dev/null; then
  echo "missing expected failing line number" >&2
  exit 1
fi
