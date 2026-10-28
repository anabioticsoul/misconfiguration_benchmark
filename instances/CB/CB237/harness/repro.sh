#!/usr/bin/env bash
set -euo pipefail

DATA_DIR=/opt/cb237/data
LOG=/opt/cb237/logs/repro-postgres.log
PG_CTL=/usr/lib/postgresql/14/bin/pg_ctl
PSQL=/usr/lib/postgresql/14/bin/psql
GOSU=/usr/local/bin/gosu
cleanup() {
  rc=$?
  if [ "$rc" -ne 0 ] && [ -f "$LOG" ]; then
    cat "$LOG" >&2
  fi
  "$GOSU" postgres "$PG_CTL" -D "$DATA_DIR" -m fast -w stop >/dev/null 2>&1 || true
  exit "$rc"
}
trap cleanup EXIT

"$GOSU" postgres sh -c ': > "$1"' sh "$LOG"
if ! "$GOSU" postgres "$PG_CTL" -D "$DATA_DIR" -o '-p 5432 -h 127.0.0.1' -w start -l "$LOG"; then
  cat "$LOG" >&2
  exit 1
fi

set +e
output=$(PGSERVICEFILE=/opt/cb237/pg_service.conf PGCONNECT_TIMEOUT=2 \
  "$PSQL" service=raw_data -c 'SELECT 1' 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -ne 0 ]
[[ "$output" == *"Connection refused"* ]]
