#!/usr/bin/env bash
set -euo pipefail

DATA_DIR=/opt/cb237/data
LOG=/opt/cb237/logs/p2p-postgres.log
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

output=$(PGPASSWORD=my_password "$PSQL" -h 127.0.0.1 -p 5432 -U my_username \
  -d raw_data -At -c 'SELECT current_database() || '"'"':'"'"' || current_user')
printf '%s\n' "$output"
[ "$output" = "raw_data:my_username" ]

service_text=$(cat /opt/cb237/pg_service.conf)
[[ "$service_text" == *"[raw_data]"* ]]
[[ "$service_text" == *"host="* ]]
[[ "$service_text" == *"dbname=raw_data"* ]]
[[ "$service_text" == *"user=my_username"* ]]
